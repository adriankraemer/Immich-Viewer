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
    
    // MARK: - Date Formatters
    private static let isoFormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
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
                self.albums = sortAlbums(fetchedAlbums)
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
    
    /// Sorts albums based on the user's albumListSortOrder setting
    private func sortAlbums(_ albums: [ImmichAlbum]) -> [ImmichAlbum] {
        let sortOrder = UserDefaults.standard.albumListSortOrder
        
        switch sortOrder {
        case "newestFirst":
            // Sort by endDate (newest photo in album) descending
            return albums.sorted { lhs, rhs in
                let lhsDate = parseDate(lhs.endDate) ?? .distantPast
                let rhsDate = parseDate(rhs.endDate) ?? .distantPast
                if lhsDate == rhsDate {
                    return lhs.albumName.localizedCaseInsensitiveCompare(rhs.albumName) == .orderedAscending
                }
                return lhsDate > rhsDate
            }
        case "oldestFirst":
            // Sort by startDate (oldest photo in album) ascending
            return albums.sorted { lhs, rhs in
                let lhsDate = parseDate(lhs.startDate) ?? .distantFuture
                let rhsDate = parseDate(rhs.startDate) ?? .distantFuture
                if lhsDate == rhsDate {
                    return lhs.albumName.localizedCaseInsensitiveCompare(rhs.albumName) == .orderedAscending
                }
                return lhsDate < rhsDate
            }
        default:
            // "alphabetical" - Sort by album name A-Z
            return albums.sorted { $0.albumName.localizedCaseInsensitiveCompare($1.albumName) == .orderedAscending }
        }
    }
    
    /// Parses ISO8601 date strings
    private func parseDate(_ value: String?) -> Date? {
        guard let value = value else { return nil }
        if let date = Self.isoFormatterWithFractional.date(from: value) {
            return date
        }
        return Self.isoFormatter.date(from: value)
    }
}

