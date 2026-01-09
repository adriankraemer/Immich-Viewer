import SwiftUI
import AVKit

// MARK: - Theme Constants
private enum VideoPlayerTheme {
    static let accent = Color(red: 245/255, green: 166/255, blue: 35/255)
    static let surface = Color(red: 30/255, green: 30/255, blue: 32/255)
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 180/255, green: 180/255, blue: 185/255)
}

/// Optimized video player with buffering support for smooth playback
struct SimpleVideoPlayerView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel: SimpleVideoPlayerViewModel
    
    // MARK: - Local State
    @State private var loadingRotation: Double = 0
    
    // MARK: - Initialization
    
    init(
        asset: ImmichAsset,
        assetService: AssetService,
        authenticationService: AuthenticationService
    ) {
        _viewModel = StateObject(wrappedValue: SimpleVideoPlayerViewModel(
            asset: asset,
            assetService: assetService,
            authenticationService: authenticationService
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let player = viewModel.player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            }
            
            // Loading overlay with progress
            if viewModel.isLoading {
                loadingView
            }
            
            // Buffering overlay (shown during playback when rebuffering)
            if viewModel.isBuffering && !viewModel.isLoading {
                bufferingOverlay
            }
            
            // Error view with retry options
            if let message = viewModel.errorMessage {
                errorView(message: message)
            }
        }
        .task {
            await viewModel.loadVideoIfNeeded()
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            // Animated loading ring with progress
            ZStack {
                // Background ring
                Circle()
                    .stroke(VideoPlayerTheme.surface, lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: CGFloat(viewModel.loadingProgress))
                    .stroke(
                        VideoPlayerTheme.accent,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: viewModel.loadingProgress)
                
                // Spinning indicator when progress is 0
                if viewModel.loadingProgress < 0.01 {
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            AngularGradient(
                                colors: [VideoPlayerTheme.accent, VideoPlayerTheme.accent.opacity(0.3)],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(loadingRotation))
                }
                
                // Percentage text
                if viewModel.loadingProgress > 0.01 {
                    Text("\(viewModel.bufferPercentage)%")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(VideoPlayerTheme.textPrimary)
                }
            }
            
            VStack(spacing: 8) {
                Text(String(localized: "Loading Video"))
                    .font(.headline)
                    .foregroundColor(VideoPlayerTheme.textPrimary)
                
                if !viewModel.bufferStatus.isEmpty {
                    Text(viewModel.bufferStatus)
                        .font(.subheadline)
                        .foregroundColor(VideoPlayerTheme.textSecondary)
                }
            }
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        )
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                loadingRotation = 360
            }
        }
    }
    
    // MARK: - Buffering Overlay
    
    private var bufferingOverlay: some View {
        VStack(spacing: 16) {
            // Buffer progress indicator
            ZStack {
                Circle()
                    .stroke(VideoPlayerTheme.surface.opacity(0.5), lineWidth: 3)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: CGFloat(viewModel.bufferPercentage) / 100.0)
                    .stroke(
                        VideoPlayerTheme.accent,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.2), value: viewModel.bufferPercentage)
                
                Text("\(viewModel.bufferPercentage)%")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(VideoPlayerTheme.textPrimary)
            }
            
            Text(String(localized: "Buffering"))
                .font(.callout)
                .foregroundColor(VideoPlayerTheme.textSecondary)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            // Error icon
            ZStack {
                Circle()
                    .fill(VideoPlayerTheme.surface)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 45))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.orange, Color.red],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            VStack(spacing: 12) {
                Text(String(localized: "Unable to Play Video"))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(VideoPlayerTheme.textPrimary)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(VideoPlayerTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            
            // Action buttons
            VStack(spacing: 12) {
                Button(action: {
                    Task {
                        await viewModel.retry()
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.clockwise")
                        Text(String(localized: "Try Again"))
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(VideoPlayerTheme.accent)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Alternative retry button for auth issues
                if message.lowercased().contains("auth") || message.lowercased().contains("sign in") {
                    Button(action: {
                        Task {
                            await viewModel.retryWithFallback()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "key")
                            Text(String(localized: "Try Different Auth Method"))
                        }
                        .font(.subheadline)
                        .foregroundColor(VideoPlayerTheme.textSecondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 4)
                }
            }
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        )
    }
}

// MARK: - Preview

#Preview {
    let sampleAsset = ImmichAsset(
        id: "sample-video-1",
        deviceAssetId: "device-1",
        deviceId: "device-1",
        ownerId: "owner-1",
        libraryId: "library-1",
        type: .video,
        originalPath: "/sample/video.mp4",
        originalFileName: "video.mp4",
        originalMimeType: "video/mp4",
        resized: false,
        thumbhash: nil,
        fileModifiedAt: "2024-01-01T00:00:00Z",
        fileCreatedAt: "2024-01-01T00:00:00Z",
        localDateTime: "2024-01-01T00:00:00Z",
        updatedAt: "2024-01-01T00:00:00Z",
        isFavorite: false,
        isArchived: false,
        isOffline: false,
        isTrashed: false,
        checksum: "sample-checksum",
        duration: "00:01:30",
        hasMetadata: true,
        livePhotoVideoId: nil,
        people: [],
        visibility: "VISIBLE",
        duplicateId: nil,
        exifInfo: nil
    )
    
    let userManager = UserManager()
    let networkService = NetworkService(userManager: userManager)
    let authenticationService = AuthenticationService(networkService: networkService, userManager: userManager)
    let assetService = AssetService(networkService: networkService)
    
    return SimpleVideoPlayerView(
        asset: sampleAsset,
        assetService: assetService,
        authenticationService: authenticationService
    )
}
