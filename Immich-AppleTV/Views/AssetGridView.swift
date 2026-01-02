import SwiftUI

struct AssetGridView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel: AssetGridViewModel
    
    // MARK: - Services (for child views)
    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    
    // MARK: - Configuration
    let deepLinkAssetId: String?
    
    // MARK: - Local State
    @State private var showingFullScreen = false
    @State private var showingSlideshow = false
    @FocusState private var focusedAssetId: String?
    @State private var isProgrammaticFocusChange = false
    @State private var shouldScrollToAsset: String?
    
    // MARK: - Layout
    private let columns = [
        GridItem(.fixed(300), spacing: 50),
        GridItem(.fixed(300), spacing: 50),
        GridItem(.fixed(300), spacing: 50),
        GridItem(.fixed(300), spacing: 50),
        GridItem(.fixed(300), spacing: 50),
    ]
    
    // MARK: - Initialization
    
    init(
        assetService: AssetService,
        authService: AuthenticationService,
        assetProvider: AssetProvider,
        albumId: String?,
        personId: String?,
        tagId: String?,
        city: String?,
        isAllPhotos: Bool,
        isFavorite: Bool,
        onAssetsLoaded: (([ImmichAsset]) -> Void)?,
        deepLinkAssetId: String?
    ) {
        self.assetService = assetService
        self.authService = authService
        self.deepLinkAssetId = deepLinkAssetId
        
        _viewModel = StateObject(wrappedValue: AssetGridViewModel(
            assetService: assetService,
            authService: authService,
            assetProvider: assetProvider,
            albumId: albumId,
            personId: personId,
            tagId: tagId,
            city: city,
            isAllPhotos: isAllPhotos,
            isFavorite: isFavorite,
            onAssetsLoaded: onAssetsLoaded
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            SharedGradientBackground()
            
            if viewModel.isLoading {
                loadingView
            } else if let errorMessage = viewModel.errorMessage {
                errorView(message: errorMessage)
            } else if viewModel.assets.isEmpty {
                emptyStateView
            } else {
                assetsGridView
            }
        }
        .fullScreenCover(isPresented: $showingFullScreen) {
            if let selectedAsset = viewModel.selectedAsset {
                FullScreenImageView(
                    asset: selectedAsset,
                    assets: viewModel.assets,
                    currentIndex: viewModel.assets.firstIndex(of: selectedAsset) ?? 0,
                    assetService: assetService,
                    authenticationService: authService,
                    currentAssetIndex: $viewModel.currentAssetIndex
                )
            }
        }
        .fullScreenCover(isPresented: $showingSlideshow) {
            if !viewModel.imageAssets.isEmpty {
                SlideshowView(
                    assetService: assetService,
                    albumService: nil,
                    albumId: viewModel.albumId,
                    personId: viewModel.personId,
                    tagId: viewModel.tagId,
                    city: viewModel.city,
                    startingAssetId: viewModel.getSlideshowStartingAssetId(),
                    isFavorite: viewModel.isFavorite,
                    isAllPhotos: viewModel.isAllPhotos
                )
            }
        }
        .onPlayPauseCommand {
            debugLog("Play pause tapped in AssetGridView - starting slideshow")
            startSlideshow()
        }
        .onAppear {
            debugLog("AssetGridView appeared")
            if viewModel.assets.isEmpty {
                viewModel.loadAssets()
            }
        }
        .onDisappear {
            viewModel.cancelPendingLoads()
        }
        .onChange(of: showingFullScreen) { _, isShowing in
            handleFullScreenDismiss(isShowing: isShowing)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name(NotificationNames.startAutoSlideshow))) { _ in
            startSlideshow()
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        ProgressView("Loading photos...")
            .foregroundColor(.white)
            .scaleEffect(1.5)
    }
    
    private func errorView(message: String) -> some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            Text("Error")
                .font(.title)
                .foregroundColor(.white)
            Text(message)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
            Button("Retry") {
                viewModel.loadAssets()
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var emptyStateView: some View {
        VStack {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text(viewModel.emptyStateTitle)
                .font(.title)
                .foregroundColor(.white)
            Text(viewModel.emptyStateMessage)
                .foregroundColor(.gray)
        }
    }
    
    private var assetsGridView: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 50) {
                        ForEach(viewModel.assets) { asset in
                            assetButton(for: asset)
                        }
                        
                        // Loading indicator at the bottom
                        if viewModel.isLoadingMore {
                            loadingMoreIndicator
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                    .onChange(of: focusedAssetId) { oldValue, newFocusedId in
                        handleFocusChange(newFocusedId: newFocusedId, proxy: proxy)
                    }
                    .onChange(of: shouldScrollToAsset) { oldValue, assetId in
                        handleScrollToAsset(assetId: assetId, proxy: proxy)
                    }
                    .onChange(of: deepLinkAssetId) { oldValue, assetId in
                        handleDeepLink(assetId: assetId)
                    }
                }
            }
        }
    }
    
    private func assetButton(for asset: ImmichAsset) -> some View {
        Button(action: {
            viewModel.selectAsset(asset)
            showingFullScreen = true
        }) {
            AssetThumbnailView(
                asset: asset,
                assetService: assetService,
                isFocused: focusedAssetId == asset.id
            )
        }
        .frame(width: 300, height: 360)
        .id(asset.id)
        .focused($focusedAssetId, equals: asset.id)
        .animation(.easeInOut(duration: 0.2), value: focusedAssetId)
        .onAppear {
            handleAssetAppear(asset: asset)
        }
        .buttonStyle(CardButtonStyle())
    }
    
    private var loadingMoreIndicator: some View {
        HStack {
            Spacer()
            ProgressView("Loading more...")
                .foregroundColor(.white)
                .scaleEffect(1.2)
            Spacer()
        }
        .frame(height: 100)
        .padding()
    }
    
    // MARK: - Event Handlers
    
    private func handleAssetAppear(asset: ImmichAsset) {
        if viewModel.shouldLoadMore(for: asset) {
            viewModel.debouncedLoadMore()
        }
        
        if shouldScrollToAsset == asset.id {
            debugLog("AssetGridView: Target asset appeared in grid - \(asset.id)")
        }
    }
    
    private func handleFocusChange(newFocusedId: String?, proxy: ScrollViewProxy) {
        debugLog("AssetGridView: focusedAssetId changed to \(newFocusedId ?? "nil"), isProgrammatic: \(isProgrammaticFocusChange)")
        
        if let focusedId = newFocusedId {
            viewModel.updateCurrentIndex(for: focusedId)
            
            if isProgrammaticFocusChange {
                debugLog("AssetGridView: Programmatic focus change - scrolling to asset ID: \(focusedId)")
                withAnimation(.easeInOut(duration: 0.5)) {
                    proxy.scrollTo(focusedId, anchor: .center)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isProgrammaticFocusChange = false
                }
            } else {
                debugLog("AssetGridView: User navigation - not scrolling")
            }
        }
    }
    
    private func handleScrollToAsset(assetId: String?, proxy: ScrollViewProxy) {
        if let assetId = assetId {
            debugLog("AssetGridView: shouldScrollToAsset triggered - scrolling to asset ID: \(assetId)")
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.5)) {
                    proxy.scrollTo(assetId, anchor: .center)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                shouldScrollToAsset = nil
            }
        }
    }
    
    private func handleDeepLink(assetId: String?) {
        if let assetId = assetId {
            debugLog("AssetGridView: Deep link asset ID received: \(assetId)")
            if viewModel.handleDeepLinkAsset(assetId) {
                focusedAssetId = assetId
                isProgrammaticFocusChange = true
            } else {
                // Asset not found, try again after loading
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if viewModel.handleDeepLinkAsset(assetId) {
                        focusedAssetId = assetId
                        isProgrammaticFocusChange = true
                    }
                }
            }
        }
    }
    
    private func handleFullScreenDismiss(isShowing: Bool) {
        debugLog("AssetGridView: showingFullScreen changed to \(isShowing)")
        
        if !isShowing && viewModel.currentAssetIndex < viewModel.assets.count {
            let currentAsset = viewModel.assets[viewModel.currentAssetIndex]
            debugLog("AssetGridView: Fullscreen dismissed, currentAssetIndex: \(viewModel.currentAssetIndex), asset ID: \(currentAsset.id)")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                debugLog("AssetGridView: Setting shouldScrollToAsset to \(currentAsset.id)")
                shouldScrollToAsset = currentAsset.id
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    debugLog("AssetGridView: Setting focusedAssetId to \(currentAsset.id)")
                    isProgrammaticFocusChange = true
                    focusedAssetId = currentAsset.id
                }
            }
        }
    }
    
    private func startSlideshow() {
        NotificationCenter.default.post(name: NSNotification.Name("stopAutoSlideshowTimer"), object: nil)
        showingSlideshow = true
    }
}
