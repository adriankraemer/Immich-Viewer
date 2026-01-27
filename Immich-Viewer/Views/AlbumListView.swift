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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name(NotificationNames.refreshAllTabs))) { _ in
            viewModel.loadAlbums()
            viewModel.loadFavoritesCount()
        }
    }
}

// MARK: - Album Detail View

struct AlbumDetailView: View {
    let album: ImmichAlbum
    @ObservedObject var albumService: AlbumService
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var assetService: AssetService
    
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
                    folderPath: nil,
                    isAllPhotos: false,
                    isFavorite: album.id.hasPrefix("smart_") ? true : false,
                    onAssetsLoaded: nil,
                    deepLinkAssetId: nil,
                    albumService: albumService
                )
            }
            .navigationTitle(album.albumName)
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
}

// MARK: - Preview

#Preview {
    let (_, userManager, authService, assetService, albumService, _, _, _) =
         MockServiceFactory.createMockServices()
    AlbumListView(albumService: albumService, authService: authService, assetService: assetService, userManager: userManager)
}
