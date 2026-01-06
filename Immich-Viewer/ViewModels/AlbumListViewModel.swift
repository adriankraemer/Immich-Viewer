import Foundation
import SwiftUI

@MainActor
class AlbumListViewModel: ObservableObject {
    // MARK: - Published Properties (View State)
    @Published var albums: [ImmichAlbum] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var favoritesCount: Int = 0
    @Published var firstFavoriteAssetId: String?
    @Published var selectedAlbum: ImmichAlbum?
    
    // MARK: - Dependencies
    private let albumService: AlbumService
    private let assetService: AssetService
    private let authService: AuthenticationService
    private let userManager: UserManager
    
    // MARK: - Computed Properties
    
    /// Returns all albums including the synthetic favorites album
    var allAlbums: [ImmichAlbum] {
        var result = albums
        if let favAlbum = createFavoritesAlbum() {
            result.insert(favAlbum, at: 0)
        }
        return result
    }
    
    // MARK: - Initialization
    
    init(
        albumService: AlbumService,
        assetService: AssetService,
        authService: AuthenticationService,
        userManager: UserManager
    ) {
        self.albumService = albumService
        self.assetService = assetService
        self.authService = authService
        self.userManager = userManager
    }
    
    // MARK: - Public Methods
    
    /// Loads albums from the service
    func loadAlbums() {
        debugLog("AlbumListViewModel: loadAlbums called - isAuthenticated: \(authService.isAuthenticated)")
        guard authService.isAuthenticated else {
            errorMessage = "Not authenticated. Please check your credentials."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedAlbums = try await albumService.fetchAlbums()
                debugLog("AlbumListViewModel: Successfully fetched \(fetchedAlbums.count) albums")
                self.albums = fetchedAlbums
                self.isLoading = false
            } catch {
                debugLog("AlbumListViewModel: Error fetching albums: \(error)")
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    /// Loads the favorites count for the synthetic favorites album
    func loadFavoritesCount() {
        guard authService.isAuthenticated else { return }
        
        Task {
            do {
                let result = try await assetService.fetchAssets(page: 1, limit: nil, isFavorite: true)
                debugLog("AlbumListViewModel: Fetched favorites count: \(result.total)")
                self.favoritesCount = result.total
                self.firstFavoriteAssetId = result.assets.first?.id
            } catch {
                debugLog("AlbumListViewModel: Failed to fetch favorites count: \(error)")
            }
        }
    }
    
    /// Selects an album
    func selectAlbum(_ album: ImmichAlbum) {
        debugLog("AlbumListViewModel: Album selected: \(album.id)")
        selectedAlbum = album
    }
    
    /// Clears the selected album
    func clearSelection() {
        selectedAlbum = nil
    }
    
    /// Retries loading albums
    func retry() {
        loadAlbums()
    }
    
    /// Loads albums if not already loaded
    func loadAlbumsIfNeeded() {
        if albums.isEmpty && !isLoading {
            loadAlbums()
            loadFavoritesCount()
        }
    }
    
    // MARK: - Private Methods
    
    /// Creates a synthetic favorites album
    private func createFavoritesAlbum() -> ImmichAlbum? {
        guard let user = userManager.currentUser else { return nil }
        
        let owner = Owner(
            id: user.id,
            email: user.email,
            name: user.name,
            profileImagePath: "",
            profileChangedAt: "",
            avatarColor: "primary"
        )
        
        return ImmichAlbum(
            id: "smart_favorites",
            albumName: "Favorites",
            description: "Collection",
            albumThumbnailAssetId: firstFavoriteAssetId,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            albumUsers: [],
            assets: [],
            assetCount: favoritesCount,
            ownerId: user.id,
            owner: owner,
            shared: false,
            hasSharedLink: false,
            isActivityEnabled: false,
            lastModifiedAssetTimestamp: nil,
            order: nil,
            startDate: nil,
            endDate: nil
        )
    }
}

