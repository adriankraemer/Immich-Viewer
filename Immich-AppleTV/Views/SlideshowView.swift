import SwiftUI
import UIKit

struct SlideshowView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel: SlideshowViewModel
    
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    
    // MARK: - Local State
    @State private var showPauseNotification = false
    
    // MARK: - Initialization
    
    init(
        assetService: AssetService,
        albumService: AlbumService?,
        albumId: String? = nil,
        personId: String? = nil,
        tagId: String? = nil,
        city: String? = nil,
        startingAssetId: String? = nil,
        isFavorite: Bool = false,
        isAllPhotos: Bool = false
    ) {
        _viewModel = StateObject(wrappedValue: SlideshowViewModel(
            assetService: assetService,
            albumService: albumService,
            albumId: albumId,
            personId: personId,
            tagId: tagId,
            city: city,
            startingAssetId: startingAssetId,
            isFavorite: isFavorite,
            isAllPhotos: isAllPhotos
        ))
    }
    
    /// Convenience initializer that creates services internally (for backward compatibility)
    init(
        albumId: String? = nil,
        personId: String? = nil,
        tagId: String? = nil,
        city: String? = nil,
        startingAssetId: String? = nil,
        isFavorite: Bool = false,
        isAllPhotos: Bool = false
    ) {
        let userManager = UserManager()
        let networkService = NetworkService(userManager: userManager)
        let assetService = AssetService(networkService: networkService)
        let albumService = AlbumService(networkService: networkService)
        
        self.init(
            assetService: assetService,
            albumService: albumService,
            albumId: albumId,
            personId: personId,
            tagId: tagId,
            city: city,
            startingAssetId: startingAssetId,
            isFavorite: isFavorite,
            isAllPhotos: isAllPhotos
        )
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background: either solid color or Ambilight effect
            if viewModel.settings.backgroundColor == "ambilight",
               let imageData = viewModel.currentImageData {
                // Ambilight effect - blurred scaled image as background
                ambilightBackground(imageData: imageData)
            } else {
                // Solid background color
                viewModel.effectiveBackgroundColor
                    .ignoresSafeArea()
            }
            
            if viewModel.currentImageData == nil && !viewModel.isLoading {
                emptyStateView
            } else if viewModel.isLoading {
                loadingView
            } else if let imageData = viewModel.currentImageData {
                imageContentView(imageData: imageData)
            } else {
                errorView
            }
            
            // Pause/Play notification overlay
            if showPauseNotification {
                pauseNotificationView
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .focusable(true)
        .focused($isFocused)
        .onAppear {
            isFocused = true
            UIApplication.shared.isIdleTimerDisabled = true
            debugLog("SlideshowView: Display sleep disabled")
            viewModel.startSlideshow()
        }
        .onDisappear {
            viewModel.cleanup()
            UIApplication.shared.isIdleTimerDisabled = false
            debugLog("SlideshowView: Display sleep re-enabled")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            UIApplication.shared.isIdleTimerDisabled = false
            debugLog("SlideshowView: Display sleep re-enabled (app backgrounded)")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            UIApplication.shared.isIdleTimerDisabled = true
            debugLog("SlideshowView: Display sleep disabled (app foregrounded)")
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            viewModel.reloadSettings()
        }
        .onPlayPauseCommand {
            viewModel.togglePause()
            showPauseNotificationBriefly()
        }
        .onTapGesture {
            UIApplication.shared.isIdleTimerDisabled = false
            debugLog("SlideshowView: Display sleep re-enabled (tap dismiss)")
            dismiss()
        }
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        VStack {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("No images to display")
                .font(.title)
                .foregroundColor(.white)
        }
    }
    
    private var loadingView: some View {
        ProgressView("Loading...")
            .foregroundColor(.white)
            .scaleEffect(1.5)
    }
    
    private var errorView: some View {
        VStack {
            Image(systemName: "photo")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("Failed to load image")
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Ambilight Background Effect
    
    @ViewBuilder
    private func ambilightBackground(imageData: SlideshowImageData) -> some View {
        GeometryReader { geometry in
            ZStack {
                // Dark base layer
                Color.black
                
                // The actual ambilight effect - scaled up blurred image
                Image(uiImage: imageData.image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width * 1.4, height: geometry.size.height * 1.4)
                    .blur(radius: 80)
                    .saturation(1.4) // Boost colors for more vibrant effect
                    .brightness(-0.1) // Slightly darken to not overpower
                    .clipped()
                
                // Additional glow layer for more intensity at edges
                Image(uiImage: imageData.image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width * 1.6, height: geometry.size.height * 1.6)
                    .blur(radius: 120)
                    .saturation(1.6)
                    .opacity(0.6)
                    .clipped()
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 1.0), value: imageData.asset.id)
    }
    
    private var pauseNotificationView: some View {
        VStack(spacing: 16) {
            Image(systemName: viewModel.isPaused ? "pause.fill" : "play.fill")
                .font(.system(size: 80, weight: .medium))
                .foregroundColor(.white)
            
            Text(viewModel.isPaused ? "Paused" : "Playing")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        )
    }
    
    // MARK: - Helper Methods
    
    private func showPauseNotificationBriefly() {
        withAnimation(.easeOut(duration: 0.2)) {
            showPauseNotification = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeIn(duration: 0.3)) {
                showPauseNotification = false
            }
        }
    }
    
    @ViewBuilder
    private func imageContentView(imageData: SlideshowImageData) -> some View {
        GeometryReader { geometry in
            let imageWidth = geometry.size.width * viewModel.settings.dimensionMultiplier
            let imageHeight = geometry.size.height * viewModel.settings.dimensionMultiplier
            
            VStack(spacing: 0) {
                // Main image with performance optimizations
                mainImageView(imageData: imageData, geometry: geometry, imageWidth: imageWidth, imageHeight: imageHeight)
                
                // Reflection
                if viewModel.settings.enableReflections {
                    reflectionView(imageData: imageData, geometry: geometry, imageWidth: imageWidth, imageHeight: imageHeight)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func mainImageView(imageData: SlideshowImageData, geometry: GeometryProxy, imageWidth: CGFloat, imageHeight: CGFloat) -> some View {
        Image(uiImage: imageData.image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: imageWidth, height: imageHeight)
            .drawingGroup()
            .offset(viewModel.isTransitioning ? viewModel.slideDirection.offset(for: geometry.size) : viewModel.kenBurnsOffset)
            .scaleEffect(viewModel.isTransitioning ? viewModel.slideDirection.scale : viewModel.kenBurnsScale)
            .opacity(viewModel.isTransitioning ? viewModel.slideDirection.opacity : 1.0)
            .animation(.easeInOut(duration: viewModel.slideAnimationDuration), value: viewModel.isTransitioning)
            .animation(.linear(duration: viewModel.settings.slideInterval), value: viewModel.kenBurnsScale)
            .animation(.linear(duration: viewModel.settings.slideInterval), value: viewModel.kenBurnsOffset)
            .overlay(
                overlayContent(imageData: imageData, geometry: geometry, imageWidth: imageWidth, imageHeight: imageHeight)
            )
    }
    
    @ViewBuilder
    private func overlayContent(imageData: SlideshowImageData, geometry: GeometryProxy, imageWidth: CGFloat, imageHeight: CGFloat) -> some View {
        if !viewModel.settings.hideOverlay {
            GeometryReader { imageGeometry in
                let actualImageSize = viewModel.calculateActualImageSize(
                    imageSize: CGSize(width: imageData.image.size.width, height: imageData.image.size.height),
                    containerSize: CGSize(width: imageWidth, height: imageHeight)
                )
                let screenWidth = geometry.size.width
                let isSmallWidth = actualImageSize.width < (screenWidth / 2)
                
                if isSmallWidth {
                    // For small images, show overlay outside
                    VStack {
                        HStack {
                            Spacer()
                            LockScreenStyleOverlay(asset: imageData.asset, isSlideshowMode: true)
                                .opacity(viewModel.isTransitioning ? 0.0 : 1.0)
                                .animation(.easeInOut(duration: viewModel.slideAnimationDuration), value: viewModel.isTransitioning)
                        }
                    }
                } else {
                    // For larger images, constrain overlay inside image
                    let xOffset = (imageWidth - actualImageSize.width) / 2
                    let yOffset = (imageHeight - actualImageSize.height) / 2
                    
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            LockScreenStyleOverlay(asset: imageData.asset, isSlideshowMode: true)
                                .opacity(viewModel.isTransitioning ? 0.0 : 1.0)
                                .animation(.easeInOut(duration: viewModel.slideAnimationDuration), value: viewModel.isTransitioning)
                                .padding(.trailing, 20)
                                .padding(.bottom, 20)
                        }
                    }
                    .frame(width: actualImageSize.width, height: actualImageSize.height)
                    .offset(x: xOffset, y: yOffset)
                }
            }
        }
    }
    
    private func reflectionView(imageData: SlideshowImageData, geometry: GeometryProxy, imageWidth: CGFloat, imageHeight: CGFloat) -> some View {
        Image(uiImage: imageData.image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(y: -1)
            .frame(width: imageWidth, height: imageHeight)
            .offset(y: -imageHeight * 0.0)
            .clipped()
            .mask(
                ZStack {
                    LinearGradient(
                        colors: [.black.opacity(0.9), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                    
                    if viewModel.settings.enableKenBurns {
                        Rectangle()
                            .fill(.clear)
                            .background(
                                Rectangle()
                                    .fill(.black)
                                    .scaleEffect(viewModel.isTransitioning ? viewModel.slideDirection.scale : viewModel.kenBurnsScale)
                                    .offset(
                                        x: -(viewModel.isTransitioning ? viewModel.slideDirection.offset(for: geometry.size).width : viewModel.kenBurnsOffset.width),
                                        y: -(viewModel.isTransitioning ? viewModel.slideDirection.offset(for: geometry.size).height : viewModel.kenBurnsOffset.height) - imageHeight
                                    )
                                    .blendMode(.destinationOut)
                            )
                    }
                }
                .compositingGroup()
            )
            .opacity(0.4)
            .drawingGroup()
            .offset(viewModel.isTransitioning ? viewModel.slideDirection.offset(for: geometry.size) : viewModel.kenBurnsOffset)
            .scaleEffect(viewModel.isTransitioning ? viewModel.slideDirection.scale : viewModel.kenBurnsScale)
            .opacity(viewModel.isTransitioning ? viewModel.slideDirection.opacity * 0.4 : 0.4)
            .animation(.easeInOut(duration: viewModel.slideAnimationDuration), value: viewModel.isTransitioning)
            .animation(.linear(duration: viewModel.settings.slideInterval), value: viewModel.kenBurnsScale)
            .animation(.linear(duration: viewModel.settings.slideInterval), value: viewModel.kenBurnsOffset)
    }
}

#Preview {
    UserDefaults.standard.set("ambilight", forKey: "slideshowBackgroundColor")
    UserDefaults.standard.set("10", forKey: "slideshowInterval")
    UserDefaults.standard.set(true, forKey: "hideImageOverlay")
    UserDefaults.standard.set(true, forKey: "enableReflectionsInSlideshow")
    UserDefaults.standard.set(true, forKey: "enableKenBurnsEffect")
    
    return SlideshowView(albumId: nil, personId: nil, tagId: nil, city: nil, startingAssetId: nil, isFavorite: false)
}
