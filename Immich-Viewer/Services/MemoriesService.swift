import Foundation
import Combine

/// Service responsible for fetching "On This Day" memories from the Immich API
/// Uses Immich's native /api/memories endpoint for accurate results across all years
class MemoriesService: ObservableObject {
    private let networkService: NetworkService
    
    // MARK: - Cache
    private var cachedMemories: [Memory]?
    private var cacheDate: Date?
    
    /// Cancellables for notification subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    init(networkService: NetworkService) {
        self.networkService = networkService
        
        // Listen for user switch notifications to invalidate cache
        NotificationCenter.default.publisher(for: NSNotification.Name(NotificationNames.refreshAllTabs))
            .sink { [weak self] _ in
                self?.invalidateCache()
                debugLog("MemoriesService: Cache invalidated due to user switch")
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Fetches all "On This Day" memories using Immich's native memories API
    /// Returns memories that have at least one photo, sorted by years ago (most recent first)
    func fetchMemories() async throws -> [Memory] {
        // Check cache - valid for the same calendar day
        if let cached = cachedMemories, let cacheDate = cacheDate, Calendar.current.isDateInToday(cacheDate) {
            debugLog("MemoriesService: Returning cached memories")
            return cached
        }
        
        debugLog("MemoriesService: Fetching memories from native Immich API")
        
        // Use Immich's native /api/memories endpoint
        let immichMemories: [ImmichMemoryResponse] = try await networkService.makeRequest(
            endpoint: "/api/memories",
            method: .GET,
            body: nil as [String: Any]?,
            responseType: [ImmichMemoryResponse].self
        )
        
        debugLog("MemoriesService: Received \(immichMemories.count) memories from Immich API")
        
        // Filter for "on_this_day" type memories that match today's date and convert to our Memory model
        var memories: [Memory] = []
        for immichMemory in immichMemories {
            // Only include "on_this_day" type memories
            guard immichMemory.type == "on_this_day" else {
                debugLog("MemoriesService: Skipping memory of type '\(immichMemory.type)'")
                continue
            }
            
            // Only include memories for today's date (same month and day)
            guard immichMemory.isForToday() else {
                debugLog("MemoriesService: Skipping memory not for today (memoryAt: \(immichMemory.memoryAt))")
                continue
            }
            
            if let memory = immichMemory.toMemory(), memory.hasPhotos {
                memories.append(memory)
                debugLog("MemoriesService: Added memory for \(memory.yearsAgo) years ago with \(memory.photoCount) photos")
            }
        }
        
        // Sort by years ago (most recent first)
        memories.sort { $0.yearsAgo < $1.yearsAgo }
        
        // Cache the results
        cachedMemories = memories
        cacheDate = Date()
        
        debugLog("MemoriesService: Fetched \(memories.count) memories with photos")
        return memories
    }
    
    /// Invalidates the cache, forcing a fresh fetch on next request
    func invalidateCache() {
        cachedMemories = nil
        cacheDate = nil
        debugLog("MemoriesService: Cache invalidated")
    }
}

// MARK: - Errors

enum MemoriesError: LocalizedError {
    case invalidDate
    case noPhotosFound
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidDate:
            return String(localized: "Could not calculate memory date")
        case .noPhotosFound:
            return String(localized: "No photos found for this day")
        case .apiError(let message):
            return message
        }
    }
}
