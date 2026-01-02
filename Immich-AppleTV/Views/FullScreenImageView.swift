import SwiftUI

struct FullScreenImageView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel: FullScreenImageViewModel
    
    // MARK: - Services (for child views)
    @ObservedObject var assetService: AssetService
    @ObservedObject var authenticationService: AuthenticationService
    
    // MARK: - Bindings
    @Binding var currentAssetIndex: Int
    
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Local State
    @FocusState private var isFocused: Bool
    
    // MARK: - Initialization
    
    init(
        asset: ImmichAsset,
        assets: [ImmichAsset],
        currentIndex: Int,
        assetService: AssetService,
        authenticationService: AuthenticationService,
        currentAssetIndex: Binding<Int>
    ) {
        debugLog("FullScreenImageView: Initializing with currentIndex: \(currentIndex)")
        self.assetService = assetService
        self.authenticationService = authenticationService
        self._currentAssetIndex = currentAssetIndex
        
        _viewModel = StateObject(wrappedValue: FullScreenImageViewModel(
            asset: asset,
            assets: assets,
            currentIndex: currentIndex,
            assetService: assetService
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            SharedOpaqueBackground()
            
            if viewModel.isVideo {
                videoContent
            } else {
                imageContent
            }
            
            // EXIF info overlay
            if viewModel.showingExifInfo {
                exifInfoOverlay
            }
            
            // Swipe hint overlay
            if viewModel.showingSwipeHint && viewModel.hasMultipleAssets {
                swipeHintOverlay
            }
        }
        .id(viewModel.refreshToggle)
        .onExitCommand {
            if viewModel.handleExitCommand() {
                dismiss()
            }
        }
        .modifier(ContentAwareModifier(
            viewModel: viewModel,
            isFocused: $isFocused,
            onDismiss: { dismiss() }
        ))
        .onAppear {
            // Set up the callback to sync currentAssetIndex binding
            viewModel.onCurrentIndexChanged = { [self] newIndex in
                self.currentAssetIndex = newIndex
            }
        }
    }
    
    // MARK: - Video Content
    
    @ViewBuilder
    private var videoContent: some View {
        if viewModel.showingVideoPlayer {
            // Use simplified video player when user clicks play
            SimpleVideoPlayerView(
                asset: viewModel.currentAsset,
                assetService: assetService,
                authenticationService: authenticationService
            )
            .id(viewModel.currentAsset.id)
        } else {
            // Show video thumbnail with play button overlay
            VideoThumbnailView(
                asset: viewModel.currentAsset,
                assetService: assetService,
                onPlayButtonTapped: {
                    viewModel.showVideoPlayer()
                }
            )
        }
    }
    
    // MARK: - Image Content
    
    @ViewBuilder
    private var imageContent: some View {
        if viewModel.isLoading {
            ProgressView("Loading...")
                .foregroundColor(.white)
                .scaleEffect(1.5)
        } else if let image = viewModel.image {
            GeometryReader { geometry in
                ZStack {
                    SharedOpaqueBackground()
                    
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .overlay(
                            // Lock screen style overlay in bottom right
                            Group {
                                if !UserDefaults.standard.hideImageOverlay {
                                    VStack {
                                        Spacer()
                                        HStack {
                                            Spacer()
                                            LockScreenStyleOverlay(asset: viewModel.currentAsset)
                                        }
                                    }
                                }
                            }
                        )
                }
            }
            .ignoresSafeArea()
        } else {
            VStack {
                Image(systemName: "photo")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                Text("Failed to load image")
                    .foregroundColor(.gray)
            }
        }
    }
    
    // MARK: - EXIF Info Overlay
    
    private var exifInfoOverlay: some View {
        VStack {
            Spacer()
            ExifInfoOverlay(asset: viewModel.currentAsset) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.hideExifInfo()
                }
            }
        }
        .transition(.opacity)
    }
    
    // MARK: - Swipe Hint Overlay
    
    private var swipeHintOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    HStack(spacing: 50) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.left")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.7))
                            Image(systemName: "arrow.right")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.7))
                            Text("Swipe to navigate")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.up")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.7))
                            Image(systemName: "arrow.down")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.7))
                            Text("Swipe up or down to show/hide details")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(20)
                }
                Spacer()
            }
            .padding(.bottom, 100)
        }
        .transition(.opacity)
    }
}

// MARK: - Content Aware Modifier

struct ContentAwareModifier: ViewModifier {
    @ObservedObject var viewModel: FullScreenImageViewModel
    @FocusState.Binding var isFocused: Bool
    let onDismiss: () -> Void
    
    func body(content: Content) -> some View {
        if viewModel.isVideo && viewModel.showingVideoPlayer {
            // For video players: no focus, no gestures, no interference
            content
        } else {
            // For images: full navigation support
            content
                .focusable(true)
                .focused($isFocused)
                .onAppear {
                    viewModel.loadFullImage()
                    viewModel.showSwipeHintIfNeeded()
                    isFocused = true
                }
                .onTapGesture {
                    viewModel.handleTap()
                }
                .onChange(of: isFocused) { oldValue, newValue in
                    debugLog("FullScreenImageView focus: \(newValue)")
                }
                .onMoveCommand { direction in
                    switch direction {
                    case .left:
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.navigateLeft()
                        }
                    case .right:
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.navigateRight()
                        }
                    case .up:
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.toggleExifInfo()
                        }
                    case .down:
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.hideExifInfo()
                        }
                    @unknown default:
                        debugLog("FullScreenImageView: Unknown direction")
                    }
                }
                .onPlayPauseCommand {
                    debugLog("Play pause tapped")
                }
                .contentShape(Rectangle())
        }
    }
}

// MARK: - Video Thumbnail View

struct VideoThumbnailView: View {
    let asset: ImmichAsset
    let assetService: AssetService
    let onPlayButtonTapped: () -> Void
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    
    @State private var thumbnail: UIImage?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack {
            SharedOpaqueBackground()
            
            if isLoading {
                ProgressView("Loading thumbnail...")
                    .foregroundColor(.white)
                    .scaleEffect(1.5)
            } else if let errorMessage = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    Text("Error Loading Video")
                        .font(.title)
                        .foregroundColor(.white)
                    Text(errorMessage)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Retry") {
                        loadThumbnailForVideo()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if let thumbnail = thumbnail {
                GeometryReader { geometry in
                    ZStack {
                        SharedOpaqueBackground()
                        
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .overlay(
                                // Play button overlay
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.7))
                                        .frame(width: 120, height: 120)
                                    
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.white)
                                        .offset(x: 5) // Slight offset to center the play icon
                                }
                                    .scaleEffect(isFocused ? 1.1 : 1.0)
                                    .animation(.easeInOut(duration: 0.2), value: isFocused)
                            )
                            .overlay(
                                // Lock screen style overlay in bottom right
                                Group {
                                    if !UserDefaults.standard.hideImageOverlay {
                                        VStack {
                                            Spacer()
                                            HStack {
                                                Spacer()
                                                LockScreenStyleOverlay(asset: asset)
                                            }
                                        }
                                    }
                                }
                            )
                    }
                }
                .ignoresSafeArea()
            } else {
                VStack {
                    Image(systemName: "video")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("Failed to load video thumbnail")
                        .foregroundColor(.gray)
                }
            }
        }
        .focusable(true)
        .focused($isFocused)
        .onAppear {
            loadThumbnailForVideo()
        }
        .onTapGesture {
            onPlayButtonTapped()
        }
    }
    
    private func loadThumbnailForVideo() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                debugLog("Loading thumbnail for video asset \(asset.id)")
                let thumbnailImage = try await thumbnailCache.getThumbnail(for: asset.id, size: "preview") {
                    // Load from server if not in cache
                    try await assetService.loadImage(assetId: asset.id, size: "preview")
                }
                await MainActor.run {
                    debugLog("Loaded thumbnail for video asset \(asset.id)")
                    self.thumbnail = thumbnailImage
                    self.isLoading = false
                }
            } catch {
                debugLog("Failed to load thumbnail for video asset \(asset.id): \(error)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleAsset = ImmichAsset(
        id: "sample-1",
        deviceAssetId: "device-1",
        deviceId: "device-1",
        ownerId: "owner-1",
        libraryId: "library-1",
        type: .image,
        originalPath: "/sample/path",
        originalFileName: "sample.jpg",
        originalMimeType: "image/jpeg",
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
        duration: nil,
        hasMetadata: true,
        livePhotoVideoId: nil,
        people: [],
        visibility: "VISIBLE",
        duplicateId: nil,
        exifInfo: ExifInfo(
            make: "Apple",
            model: "iPhone 15",
            imageName: "Sample Image",
            exifImageWidth: 1080,
            exifImageHeight: 1920,
            dateTimeOriginal: "2024-01-01T00:00:00Z",
            modifyDate: "2024-01-01T00:00:00Z",
            lensModel: "iPhone 15 back camera",
            fNumber: 1.8,
            focalLength: 26.0,
            iso: 100,
            exposureTime: "1/60",
            latitude: 37.7749,
            longitude: -122.4194,
            city: "San Francisco",
            state: "CA",
            country: "USA",
            timeZone: "America/Los_Angeles",
            description: "Sample image for preview",
            fileSizeInByte: 1024000,
            orientation: "1",
            projectionType: nil,
            rating: 5
        )
    )
    
    let sampleAssets = [
        sampleAsset,
        ImmichAsset(
            id: "sample-2",
            deviceAssetId: "device-2",
            deviceId: "device-2",
            ownerId: "owner-1",
            libraryId: "library-1",
            type: .image,
            originalPath: "/sample/path2",
            originalFileName: "sample2.jpg",
            originalMimeType: "image/jpeg",
            resized: false,
            thumbhash: nil,
            fileModifiedAt: "2024-01-02T00:00:00Z",
            fileCreatedAt: "2024-01-02T00:00:00Z",
            localDateTime: "2024-01-02T00:00:00Z",
            updatedAt: "2024-01-02T00:00:00Z",
            isFavorite: true,
            isArchived: false,
            isOffline: false,
            isTrashed: false,
            checksum: "sample-checksum-2",
            duration: nil,
            hasMetadata: true,
            livePhotoVideoId: nil,
            people: [],
            visibility: "VISIBLE",
            duplicateId: nil,
            exifInfo: nil
        )
    ]
    
    // Use the shared mock service
    let userManager = UserManager()
    let networkService = NetworkService(userManager: userManager)
    let authenticationService = AuthenticationService(networkService: networkService, userManager: userManager)
    let assetService = AssetService(networkService: networkService)
    
    FullScreenImageView(
        asset: sampleAsset,
        assets: sampleAssets,
        currentIndex: 0,
        assetService: assetService,
        authenticationService: authenticationService,
        currentAssetIndex: .constant(0)
    )
}
