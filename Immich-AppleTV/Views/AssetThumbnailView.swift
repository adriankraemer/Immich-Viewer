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
    @State private var shimmerOffset: CGFloat = -320
    let isFocused: Bool
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Background with glassmorphism
            RoundedRectangle(cornerRadius: 16)
                .fill(ThumbnailTheme.surface.opacity(0.6))
                .frame(width: 320, height: 320)
            
            if isLoading {
                // Skeleton loading animation
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ThumbnailTheme.surface.opacity(0.8))
                    
                    // Shimmer effect
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.08),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: shimmerOffset)
                    .onAppear {
                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                            shimmerOffset = 320
                        }
                    }
                }
                .frame(width: 320, height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else if let image = image {
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 320, height: 320)
                        .clipped()
                        .cornerRadius(16)
                    
                    // Subtle gradient overlay for depth
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.clear,
                            Color.black.opacity(0.4)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .cornerRadius(16)
                }
            } else {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(ThumbnailTheme.textSecondary)
                }
            }
            
            // Video indicator with cinematic styling
            if asset.type == .video {
                VStack {
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.7))
                                .frame(width: 50, height: 50)
                            
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: "play.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .offset(x: 2)
                        }
                        .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
                        .padding(12)
                    }
                    Spacer()
                }
            }
            
            // Favorite heart indicator with glow
            if asset.isFavorite {
                VStack {
                    Spacer()
                    HStack {
                        ZStack {
                            // Glow effect
                            Image(systemName: "heart.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                                .blur(radius: 6)
                            
                            Image(systemName: "heart.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                        }
                        .padding(10)
                        Spacer()
                    }
                }
            }
            
            // Date badge with glassmorphism
            VStack(alignment: .trailing, spacing: 2) {
                Text(DateFormatter.formatSpecificISO8601(asset.exifInfo?.dateTimeOriginal ?? asset.fileCreatedAt, includeTime: false))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.6))
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.1), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                }
            )
            .padding(10)
        }
        .frame(width: 320, height: 320)
        // Cinematic card styling with golden glow on focus
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            isFocused ? ThumbnailTheme.accent.opacity(0.9) : Color.white.opacity(0.1),
                            isFocused ? ThumbnailTheme.accent.opacity(0.4) : Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isFocused ? 3 : 1
                )
        )
        .shadow(
            color: isFocused ? ThumbnailTheme.accent.opacity(0.4) : Color.black.opacity(0.3),
            radius: isFocused ? 20 : 8,
            x: 0,
            y: isFocused ? 10 : 4
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
