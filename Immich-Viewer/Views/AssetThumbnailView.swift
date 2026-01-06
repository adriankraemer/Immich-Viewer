import SwiftUI

// MARK: - Cinematic Theme Constants for Asset Thumbnail
private enum ThumbnailTheme {
    static let accent = Color(red: 245/255, green: 166/255, blue: 35/255)
    static let surface = Color(red: 30/255, green: 30/255, blue: 32/255)
    static let textSecondary = Color(red: 142/255, green: 142/255, blue: 147/255)
}

struct AssetThumbnailView: View {
    let asset: ImmichAsset
    @ObservedObject var assetService: AssetService
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadingTask: Task<Void, Never>?
    let isFocused: Bool
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Background - simple solid color for performance
            RoundedRectangle(cornerRadius: 16)
                .fill(ThumbnailTheme.surface)
                .frame(width: 320, height: 320)
            
            if isLoading {
                // Simple loading state - no animation for performance
                ProgressView()
                    .scaleEffect(1.2)
                    .frame(width: 320, height: 320)
            } else if let image = image {
                // Image with drawingGroup for GPU rendering
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 320, height: 320)
                    .clipped()
                    .cornerRadius(16)
                    .drawingGroup() // Rasterize for better scroll performance
            } else {
                // Empty state
                Image(systemName: "photo")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(ThumbnailTheme.textSecondary)
            }
            
            // Video indicator - simplified
            if asset.type == .video {
                VStack {
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.7))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "play.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .offset(x: 2)
                        }
                        .padding(10)
                    }
                    Spacer()
                }
            }
            
            // Favorite heart indicator - simplified, no blur
            if asset.isFavorite {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding(10)
                        Spacer()
                    }
                }
            }
            
            // Date badge - simplified background
            Text(DateFormatter.formatSpecificISO8601(asset.exifInfo?.dateTimeOriginal ?? asset.fileCreatedAt, includeTime: false))
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.6))
                )
                .padding(10)
        }
        .frame(width: 320, height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        // Simplified border - solid color instead of gradient when not focused
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isFocused ? ThumbnailTheme.accent : Color.white.opacity(0.08),
                    lineWidth: isFocused ? 3 : 1
                )
        )
        // Only apply shadow when focused for performance
        .shadow(
            color: isFocused ? ThumbnailTheme.accent.opacity(0.35) : Color.clear,
            radius: isFocused ? 15 : 0,
            x: 0,
            y: isFocused ? 8 : 0
        )
        .onAppear {
            loadThumbnail()
        }
        .onDisappear {
            // Disable this, I think its slowing down stuff.
            // cancelLoading()
        }
    }
    
    private func loadThumbnail() {
        // Cancel any existing loading task
        loadingTask?.cancel()
        
        loadingTask = Task {
            do {
                // Check if task was cancelled before starting
                try Task.checkCancellation()
                
                let thumbnail = try await thumbnailCache.getThumbnail(for: asset.id, size: "thumbnail") {
                    // Check cancellation before network request
                    try Task.checkCancellation()
                    // Load from server if not in cache
                    return try await assetService.loadImage(assetId: asset.id, size: "thumbnail")
                }
                
                // Check cancellation before UI update
                try Task.checkCancellation()
                
                await MainActor.run {
                    self.image = thumbnail
                    self.isLoading = false
                }
            } catch is CancellationError {
                // Task was cancelled - don't update UI or log error
                debugLog("Thumbnail loading cancelled for asset \(asset.id)")
            } catch {
                debugLog("Failed to load thumbnail for asset \(asset.id): \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func cancelLoading() {
        loadingTask?.cancel()
        loadingTask = nil
    }
    
    
}

#Preview {
    let userManager = UserManager()
    let networkService = NetworkService(userManager: userManager)
    let assetService = AssetService(networkService: networkService)
    
    // Create a mock asset for preview
    let mockAsset = ImmichAsset(
        id: "mock-id",
        deviceAssetId: "mock-device-id",
        deviceId: "mock-device",
        ownerId: "mock-owner",
        libraryId: nil,
        type: .video,
        originalPath: "/mock/path",
        originalFileName: "mock.jpg",
        originalMimeType: "image/jpeg",
        resized: false,
        thumbhash: nil,
        fileModifiedAt: "2023-01-01 00:00:00",
        fileCreatedAt: "2023-12-25T14:30:00Z",
        localDateTime: "2023-01-01",
        updatedAt: "2023-01-01",
        isFavorite: true,
        isArchived: false,
        isOffline: false,
        isTrashed: false,
        checksum: "mock-checksum",
        duration: nil,
        hasMetadata: false,
        livePhotoVideoId: nil,
        people: [],
        visibility: "public",
        duplicateId: nil,
        exifInfo: nil
    )
    
    AssetThumbnailView(asset: mockAsset, assetService: assetService, isFocused: false)
} 
