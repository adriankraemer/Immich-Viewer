import SwiftUI
import AVKit

// MARK: - Native Video Player View

/// Native tvOS video player using AVPlayerViewController for full Apple Remote support
struct SimpleVideoPlayerView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel: SimpleVideoPlayerViewModel
    
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
                // Native AVPlayerViewController with full Apple Remote support
                NativeVideoPlayer(player: player)
                    .ignoresSafeArea()
            }
            
            // Loading overlay
            if viewModel.isLoading {
                loadingView
            }
            
            // Error view
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
            ProgressView()
                .scaleEffect(2)
            
            Text(String(localized: "Loading Video"))
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
            
            VStack(spacing: 12) {
                Text(String(localized: "Unable to Play Video"))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            
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
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Native Video Player (UIViewControllerRepresentable)

/// Wraps AVPlayerViewController for native tvOS video controls
/// Supports: Play/Pause button, Left/Right for scrubbing, Progress bar at bottom
struct NativeVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        
        // Start playback automatically
        player.play()
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Update player if it changes
        if uiViewController.player !== player {
            uiViewController.player = player
        }
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
