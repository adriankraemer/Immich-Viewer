import SwiftUI

// MARK: - Cinematic Theme Constants
private enum GridTheme {
    static let accent = Color(red: 245/255, green: 166/255, blue: 35/255)
    static let surface = Color(red: 30/255, green: 30/255, blue: 32/255)
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 142/255, green: 142/255, blue: 147/255)
    static let textTertiary = Color(red: 99/255, green: 99/255, blue: 102/255)
}

struct AssetGridView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel: AssetGridViewModel
    
    // MARK: - Services (for child views)
    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    
    // MARK: - Configuration
    let deepLinkAssetId: String?
    let externalSlideshowTrigger: Binding<Bool>?
    
    // MARK: - Local State
    @State private var showingFullScreen = false
    @State private var showingSlideshow = false
    @FocusState private var focusedAssetId: String?
    @State private var isProgrammaticFocusChange = false
    @State private var shouldScrollToAsset: String?
    @State private var loadingRotation: Double = 0
    
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
        folderPath: String?,
        isAllPhotos: Bool,
        isFavorite: Bool,
        onAssetsLoaded: (([ImmichAsset]) -> Void)?,
        deepLinkAssetId: String?,
        externalSlideshowTrigger: Binding<Bool>? = nil
    ) {
        self.assetService = assetService
        self.authService = authService
        self.deepLinkAssetId = deepLinkAssetId
        self.externalSlideshowTrigger = externalSlideshowTrigger
        
        _viewModel = StateObject(wrappedValue: AssetGridViewModel(
            assetService: assetService,
            authService: authService,
            assetProvider: assetProvider,
            albumId: albumId,
            personId: personId,
            tagId: tagId,
            city: city,
            folderPath: folderPath,
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
                    folderPath: viewModel.folderPath,
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
        .onChange(of: externalSlideshowTrigger?.wrappedValue ?? false) { oldValue, newValue in
            if newValue && !oldValue {
                startSlideshow()
                externalSlideshowTrigger?.wrappedValue = false
            }
        }
    }
    
    // MARK: - Subviews
    
    // MARK: - Cinematic Loading View
    private var loadingView: some View {
        VStack(spacing: 24) {
            // Animated loading ring
            CinematicLoader()
            
            Text(LocalizedStringResource("Loading photos..."))
                .font(.headline)
                .foregroundColor(GridTheme.textSecondary)
        }
    }
    
    // MARK: - Cinematic Error View
    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(GridTheme.surface)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.orange, Color.red],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            VStack(spacing: 12) {
                Text(LocalizedStringResource("Something went wrong"))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(GridTheme.textPrimary)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(GridTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }
            
            Button(action: { viewModel.loadAssets() }) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.clockwise")
                    Text(LocalizedStringResource("Try Again"))
                }
                .font(.headline)
                .foregroundColor(.black)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(GridTheme.accent)
                .cornerRadius(12)
            }
            .buttonStyle(CardButtonStyle())
        }
        .padding(40)
    }
    
    // MARK: - Cinematic Empty State
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(GridTheme.surface)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 50))
                    .foregroundColor(GridTheme.textTertiary)
            }
            
            VStack(spacing: 12) {
                Text(viewModel.emptyStateTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(GridTheme.textPrimary)
                
                Text(viewModel.emptyStateMessage)
                    .font(.body)
                    .foregroundColor(GridTheme.textSecondary)
            }
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
        HStack(spacing: 16) {
            Spacer()
            
            // Mini cinematic loader
            ZStack {
                Circle()
                    .stroke(GridTheme.surface, lineWidth: 3)
                    .frame(width: 40, height: 40)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        AngularGradient(
                            colors: [GridTheme.accent, GridTheme.accent.opacity(0.3)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(loadingRotation))
            }
            
            Text(LocalizedStringResource("Loading more..."))
                .font(.subheadline)
                .foregroundColor(GridTheme.textSecondary)
            
            Spacer()
        }
        .frame(height: 100)
        .padding()
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                loadingRotation = 360
            }
        }
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

// MARK: - Cinematic Loader Component
struct CinematicLoader: View {
    @State private var rotation: Double = 0
    
    private let accent = Color(red: 245/255, green: 166/255, blue: 35/255)
    private let accentLight = Color(red: 255/255, green: 200/255, blue: 100/255)
    private let surface = Color(red: 30/255, green: 30/255, blue: 32/255)
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(surface, lineWidth: 4)
                .frame(width: 70, height: 70)
            
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    AngularGradient(
                        colors: [accent, accentLight, accent],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 70, height: 70)
                .rotationEffect(.degrees(rotation))
        }
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}
