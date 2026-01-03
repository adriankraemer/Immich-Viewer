import SwiftUI

struct AlbumListView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel: AlbumListViewModel
    
    // MARK: - Services (for child views)
    @ObservedObject var albumService: AlbumService
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var assetService: AssetService
    @ObservedObject var userManager: UserManager
    
    // MARK: - Thumbnail Provider
    private var thumbnailProvider: AlbumThumbnailProvider {
        AlbumThumbnailProvider(albumService: albumService, assetService: assetService)
    }
    
    // MARK: - Initialization
    
    init(
        albumService: AlbumService,
        authService: AuthenticationService,
        assetService: AssetService,
        userManager: UserManager
    ) {
        self.albumService = albumService
        self.authService = authService
        self.assetService = assetService
        self.userManager = userManager
        
        _viewModel = StateObject(wrappedValue: AlbumListViewModel(
            albumService: albumService,
            assetService: assetService,
            authService: authService,
            userManager: userManager
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        SharedGridView(
            items: viewModel.allAlbums,
            config: .albumStyle,
            thumbnailProvider: thumbnailProvider,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage,
            onItemSelected: { album in
                viewModel.selectAlbum(album)
            },
            onRetry: {
                viewModel.retry()
            }
        )
        .fullScreenCover(item: $viewModel.selectedAlbum) { album in
            AlbumDetailView(
                album: album,
                albumService: albumService,
                authService: authService,
                assetService: assetService
            )
        }
        .onAppear {
            viewModel.loadAlbumsIfNeeded()
        }
    }
}

// MARK: - Cinematic Theme for Album Detail
private enum AlbumDetailTheme {
    static let accent = Color(red: 245/255, green: 166/255, blue: 35/255)
    static let surface = Color(red: 30/255, green: 30/255, blue: 32/255)
}

// MARK: - Album Detail View

struct AlbumDetailView: View {
    let album: ImmichAlbum
    @ObservedObject var albumService: AlbumService
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var assetService: AssetService
    @Environment(\.dismiss) private var dismiss
    @State private var albumAssets: [ImmichAsset] = []
    @State private var slideshowTrigger: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Cinematic background
                SharedGradientBackground()
                
                AssetGridView(
                    assetService: assetService,
                    authService: authService,
                    assetProvider: createAssetProvider(for: album),
                    albumId: album.id.hasPrefix("smart_") ? nil : album.id,
                    personId: nil,
                    tagId: nil,
                    city: nil,
                    isAllPhotos: false,
                    isFavorite: album.id.hasPrefix("smart_") ? true : false,
                    onAssetsLoaded: { loadedAssets in
                        self.albumAssets = loadedAssets
                    },
                    deepLinkAssetId: nil
                )
            }
            .navigationTitle(album.albumName)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: startSlideshow) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text("Slideshow")
                        }
                        .foregroundColor(AlbumDetailTheme.accent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AlbumDetailTheme.accent.opacity(0.15))
                        )
                    }
                    .disabled(albumAssets.isEmpty)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark")
                            Text("Close")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AlbumDetailTheme.surface.opacity(0.8))
                        )
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $slideshowTrigger) {
            SlideshowView(
                albumId: album.id.hasPrefix("smart_") ? nil : album.id,
                personId: nil,
                tagId: nil,
                city: nil,
                startingAssetId: nil,
                isFavorite: album.id == "smart_favorites"
            )
        }
        .onAppear {
            debugLog("AlbumDetailView: View appeared for album \(album.albumName)")
        }
    }
    
    private func createAssetProvider(for album: ImmichAlbum) -> AssetProvider {
        if album.id == "smart_favorites" {
            return AssetProviderFactory.createProvider(
                isFavorite: true,
                assetService: assetService
            )
        } else {
            return AssetProviderFactory.createProvider(
                albumId: album.id,
                assetService: assetService,
                albumService: albumService
            )
        }
    }
    
    private func startSlideshow() {
        // Stop auto-slideshow timer before starting slideshow
        NotificationCenter.default.post(name: NSNotification.Name("stopAutoSlideshowTimer"), object: nil)
        slideshowTrigger = true
    }
}

// MARK: - Preview

#Preview {
    let (_, userManager, authService, assetService, albumService, _, _, _) =
         MockServiceFactory.createMockServices()
    AlbumListView(albumService: albumService, authService: authService, assetService: assetService, userManager: userManager)
}
