import Foundation
import UIKit

/// Two-tier thumbnail cache (memory + disk) for efficient image loading
/// Uses NSCache for memory (auto-evicts under memory pressure) and file system for disk cache
@MainActor
class ThumbnailCache: NSObject, ObservableObject {
    static let shared = ThumbnailCache()
    
    // MARK: - Cache Configuration
    private let maxMemoryCacheSize = 100 * 1024 * 1024 // 100MB memory cache
    private let maxDiskCacheSize = 500 * 1024 * 1024 // 500MB disk cache
    private let maxMemoryCacheCount = 200 // Maximum number of images in memory
    private let cacheDirectoryName = "ThumbnailCache"
    
    // MARK: - Cache Storage
    /// Memory cache using NSCache (automatically evicts under memory pressure)
    private var memoryCache = NSCache<NSString, CachedImage>()
    /// Serial queue for disk cache operations
    private let diskCacheQueue = DispatchQueue(label: "com.immich.thumbnailcache.disk", qos: .utility)
    private let cacheDirectory: URL
    
    // MARK: - Cache Statistics
    /// Published properties for cache monitoring/debugging
    @Published var memoryCacheSize: Int = 0
    @Published var diskCacheSize: Int = 0
    @Published var memoryCacheCount: Int = 0
    
    private override init() {
        // Setup disk cache directory first - use caches directory instead of documents
        let cachesPath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesPath.appendingPathComponent(cacheDirectoryName)
        
        super.init()
        
        // Configure memory cache
        memoryCache.totalCostLimit = maxMemoryCacheSize
        memoryCache.countLimit = maxMemoryCacheCount
        memoryCache.delegate = self
        
        // Create cache directory if it doesn't exist
        do {
            if !FileManager.default.fileExists(atPath: cacheDirectory.path) {
                try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
                debugLog("📁 Created cache directory: \(cacheDirectory.path)")
            } else {
                debugLog("📁 Cache directory already exists: \(cacheDirectory.path)")
            }
            
            // Verify directory is writable
            let isWritable = FileManager.default.isWritableFile(atPath: cacheDirectory.path)
            debugLog("📁 Directory is writable: \(isWritable)")
        } catch {
            debugLog("❌ Failed to create cache directory: \(error)")
            debugLog("❌ Error details: \(error.localizedDescription)")
        }
        
        // Load initial disk cache size
        calculateDiskCacheSize()
        
        // Memory cache statistics will be updated as objects are added/removed
    }
    
    // MARK: - Public Methods
    
    /// Gets thumbnail from cache (memory first, then disk) or loads from server
    /// Implements three-tier lookup: memory -> disk -> network
    func getThumbnail(for assetId: String, size: String = "thumbnail", loadFromServer: @escaping () async throws -> UIImage?) async throws -> UIImage? {
        let cacheKey = cacheKey(for: assetId, size: size)
        
        debugLog("🔍 Looking for thumbnail: \(cacheKey)")
        
        // Check memory cache first (fastest)
        if let cachedImage = memoryCache.object(forKey: cacheKey as NSString) {
            debugLog("⚡ Memory cache hit: \(cacheKey)")
            return cachedImage.image
        }
        
        // Check disk cache (slower but no network)
        if let diskImage = await loadFromDisk(cacheKey: cacheKey) {
            // Store in memory cache
            let cachedImage = CachedImage(image: diskImage, size: diskImage.jpegData(compressionQuality: 0.8)?.count ?? 0)
            memoryCache.setObject(cachedImage, forKey: cacheKey as NSString, cost: cachedImage.size)
            
            // Update memory cache statistics
            self.memoryCacheSize += cachedImage.size
            self.memoryCacheCount += 1
            return diskImage
        }
        
        debugLog("🌐 Loading from server: \(cacheKey)")
        // Load from server
        guard let serverImage = try await loadFromServer() else {
            debugLog("❌ Failed to load from server: \(cacheKey)")
            return nil
        }
        
        debugLog("💾 Caching new image: \(cacheKey)")
        // Cache the image
        await cacheImage(serverImage, for: cacheKey)
        
        return serverImage
    }
    
    /// Preload thumbnails for better performance
    nonisolated func preloadThumbnails(for assets: [ImmichAsset], size: String = "thumbnail") {
        Task { @MainActor in
            for asset in assets {
                let cacheKey = cacheKey(for: asset.id, size: size)
                
                // Skip if already in memory cache
                if memoryCache.object(forKey: cacheKey as NSString) != nil {
                    continue
                }
                
                // Skip if already on disk
                if await isCachedOnDisk(cacheKey: cacheKey) {
                    continue
                }
                
                // Preload in background - just check if cached, actual loading happens elsewhere
                let isCached = await isCachedOnDisk(cacheKey: cacheKey)
                if !isCached {
                    debugLog("Asset \(asset.id) not cached, will be loaded on demand")
                }
            }
        }
    }
    
    /// Clear all caches
    func clearAllCaches() {
        // Clear memory cache
        memoryCache.removeAllObjects()
        
        // Reset memory cache statistics
        self.memoryCacheSize = 0
        self.memoryCacheCount = 0
        
        // Clear disk cache
        let cacheDir = self.cacheDirectory
        diskCacheQueue.async {
            try? FileManager.default.removeItem(at: cacheDir)
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
        
        // Force refresh statistics
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            self.refreshCacheStatistics()
        }
    }
    
    /// Clear expired cache entries
    func clearExpiredCache() {
        removeExpiredCacheEntries()
        
        // Force refresh statistics after clearing
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            self.refreshCacheStatistics()
        }
    }
    
    /// Refresh cache statistics (call this to update the UI)
    func refreshCacheStatistics() {
        calculateDiskCacheSize()
        updateMemoryCacheStatistics()
    }
    
    // MARK: - Private Methods
    
    private func cacheKey(for assetId: String, size: String) -> String {
        return "\(assetId)_\(size).jpg"
    }
    
    private func cacheImage(_ image: UIImage, for cacheKey: String) async {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        let cachedImage = CachedImage(image: image, size: imageData.count)
        
        // Store in memory cache
        memoryCache.setObject(cachedImage, forKey: cacheKey as NSString, cost: cachedImage.size)
        
        // Update memory cache statistics
        self.memoryCacheSize += cachedImage.size
        self.memoryCacheCount += 1
        
        // Store on disk
        await storeOnDisk(imageData: imageData, cacheKey: cacheKey)
    }
    
    private nonisolated func loadFromDisk(cacheKey: String) async -> UIImage? {
        return await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            diskCacheQueue.async { [cacheDirectory] in
                // Ensure directory exists before checking for files
                if !FileManager.default.fileExists(atPath: cacheDirectory.path) {
                    try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
                }
                
                let fileURL = cacheDirectory.appendingPathComponent(cacheKey)
                
                guard FileManager.default.fileExists(atPath: fileURL.path),
                      let imageData = try? Data(contentsOf: fileURL),
                      let image = UIImage(data: imageData) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                continuation.resume(returning: image)
            }
        }
    }
    
    private nonisolated func storeOnDisk(imageData: Data, cacheKey: String) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            diskCacheQueue.async { [cacheDirectory, maxDiskCacheSize] in
                // Ensure directory exists before writing
                if !FileManager.default.fileExists(atPath: cacheDirectory.path) {
                    try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
                }
                
                let fileURL = cacheDirectory.appendingPathComponent(cacheKey)
                
                // Check if directory exists and is writable
                let directoryExists = FileManager.default.fileExists(atPath: cacheDirectory.path)
                let isWritable = FileManager.default.isWritableFile(atPath: cacheDirectory.path)
                debugLog("📁 Directory exists: \(directoryExists), writable: \(isWritable)")
                debugLog("📁 Writing to: \(fileURL.path)")
                
                do {
                    try imageData.write(to: fileURL)
                    debugLog("✅ Cached thumbnail to disk: \(cacheKey) (\(imageData.count) bytes)")
                    let fileCount = (try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil).count) ?? 0
                    debugLog("📊 Cache directory now contains: \(fileCount) files")
                    
                    // Calculate current disk size and cleanup if needed
                    let fileURLs = try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
                    let totalSize = fileURLs?.reduce(0) { total, url in
                        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                        return total + fileSize
                    } ?? 0
                    
                    if totalSize > maxDiskCacheSize {
                        // Cleanup old files
                        if let sortedFiles = fileURLs?.sorted(by: { url1, url2 in
                            let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                            let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                            return date1 < date2
                        }) {
                            var currentSize = totalSize
                            for fileURL in sortedFiles {
                                if currentSize <= maxDiskCacheSize { break }
                                let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                                try? FileManager.default.removeItem(at: fileURL)
                                currentSize -= fileSize
                            }
                        }
                    }
                } catch {
                    debugLog("❌ Failed to store thumbnail on disk: \(error)")
                    debugLog("❌ Error details: \(error.localizedDescription)")
                }
                
                continuation.resume()
            }
        }
    }
    
    private nonisolated func isCachedOnDisk(cacheKey: String) async -> Bool {
        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            diskCacheQueue.async { [cacheDirectory] in
                // Ensure directory exists before checking for files
                if !FileManager.default.fileExists(atPath: cacheDirectory.path) {
                    try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
                }
                
                let fileURL = cacheDirectory.appendingPathComponent(cacheKey)
                let exists = FileManager.default.fileExists(atPath: fileURL.path)
                continuation.resume(returning: exists)
            }
        }
    }
    
    private func calculateDiskCacheSize() {
        let cacheDir = cacheDirectory
        Task.detached { @MainActor [weak self] in
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey])
                let totalSize = fileURLs.reduce(0) { total, url in
                    let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                    return total + fileSize
                }
                
                debugLog("📊 Disk cache calculation: \(fileURLs.count) files, \(totalSize) bytes")
                debugLog("📊 Cache directory: \(cacheDir.path)")
                
                self?.diskCacheSize = totalSize
                debugLog("📊 Updated disk cache size: \(totalSize) bytes")
            } catch {
                debugLog("❌ Failed to calculate disk cache size: \(error)")
                debugLog("❌ Cache directory: \(cacheDir.path)")
                debugLog("❌ Error details: \(error.localizedDescription)")
            }
        }
    }
    
    private func cleanupDiskCache() {
        let cacheDir = cacheDirectory
        let maxSize = maxDiskCacheSize
        let currentDiskSize = diskCacheSize
        
        Task.detached { @MainActor [weak self] in
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
                
                // Sort files by creation date (oldest first)
                let sortedFiles = fileURLs.sorted { url1, url2 in
                    let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    return date1 < date2
                }
                
                var currentSize = currentDiskSize
                
                for fileURL in sortedFiles {
                    if currentSize <= maxSize {
                        break
                    }
                    
                    let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                    try? FileManager.default.removeItem(at: fileURL)
                    currentSize -= fileSize
                }
                
                self?.diskCacheSize = currentSize
            } catch {
                debugLog("Failed to cleanup disk cache: \(error)")
            }
        }
    }
    
    private func removeExpiredCacheEntries() {
        let expirationDate = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7 days
        let cacheDir = cacheDirectory
        
        Task.detached {
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.creationDateKey])
                
                for fileURL in fileURLs {
                    if let creationDate = try? fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate,
                       creationDate < expirationDate {
                        try? FileManager.default.removeItem(at: fileURL)
                    }
                }
            } catch {
                debugLog("Failed to remove expired cache entries: \(error)")
            }
        }
        
        calculateDiskCacheSize()
    }
    
    private func updateMemoryCacheStatistics() {
        // Note: NSCache doesn't provide direct access to all objects, so we'll use our tracking
        // but also recalculate disk cache size periodically
        // Only log if there are significant changes or for debugging
        if self.memoryCacheSize > 0 || self.memoryCacheCount > 0 {
            debugLog("📊 Memory cache stats - Size: \(self.memoryCacheSize), Count: \(self.memoryCacheCount)")
        }
        
        // Recalculate disk cache size periodically
        calculateDiskCacheSize()
    }
    
    private nonisolated func ensureCacheDirectoryExists() {
        if !FileManager.default.fileExists(atPath: cacheDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
                debugLog("📁 Created cache directory: \(cacheDirectory.path)")
            } catch {
                debugLog("❌ Failed to create cache directory: \(error)")
                debugLog("❌ Error details: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - CachedImage Class
final class CachedImage: @unchecked Sendable {
    let image: UIImage
    let size: Int
    let timestamp: Date
    
    init(image: UIImage, size: Int) {
        self.image = image
        self.size = size
        self.timestamp = Date()
    }
}

// MARK: - NSCacheDelegate
extension ThumbnailCache: NSCacheDelegate {
    nonisolated func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
        if let cachedImage = obj as? CachedImage {
            let size = cachedImage.size
            Task { @MainActor [weak self] in
                self?.memoryCacheSize -= size
                self?.memoryCacheCount -= 1
            }
        }
    }
} 
