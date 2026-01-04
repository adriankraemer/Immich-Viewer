import Foundation
import SwiftUI
import Combine

@MainActor
class AssetGridViewModel: ObservableObject {
    // MARK: - Published Properties (View State)
    @Published var assets: [ImmichAsset] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var selectedAsset: ImmichAsset?
    @Published var currentAssetIndex: Int = 0
    @Published var hasMoreAssets = true
    
    // MARK: - Dependencies
    private let assetService: AssetService
    private let authService: AuthenticationService
    private let assetProvider: AssetProvider
    
    // MARK: - Configuration
    let albumId: String?
    let personId: String?
    let tagId: String?
    let city: String?
    let folderPath: String?
    let isAllPhotos: Bool
    let isFavorite: Bool
    
    // MARK: - Internal State
    private var nextPage: String?
    private var loadMoreTask: Task<Void, Never>?
    
    // MARK: - Callbacks
    var onAssetsLoaded: (([ImmichAsset]) -> Void)?
    
    // MARK: - Computed Properties
    
    var emptyStateTitle: String {
        if personId != nil {
            return "No Photos of Person"
        } else if albumId != nil {
            return "No Photos in Album"
        } else {
            return "No Photos Found"
        }
    }
    
    var emptyStateMessage: String {
        if personId != nil {
            return "This person has no photos"
        } else if albumId != nil {
            return "This album is empty"
        } else {
            return "Your photos will appear here"
        }
    }
    
    var imageAssets: [ImmichAsset] {
        assets.filter { $0.type == .image }
    }
    
    // MARK: - Initialization
    
    init(
        assetService: AssetService,
        authService: AuthenticationService,
        assetProvider: AssetProvider,
        albumId: String? = nil,
        personId: String? = nil,
        tagId: String? = nil,
        city: String? = nil,
        folderPath: String? = nil,
        isAllPhotos: Bool = false,
        isFavorite: Bool = false,
        onAssetsLoaded: (([ImmichAsset]) -> Void)? = nil
    ) {
        self.assetService = assetService
        self.authService = authService
        self.assetProvider = assetProvider
        self.albumId = albumId
        self.personId = personId
        self.tagId = tagId
        self.city = city
        self.folderPath = folderPath
        self.isAllPhotos = isAllPhotos
        self.isFavorite = isFavorite
        self.onAssetsLoaded = onAssetsLoaded
    }
    
    // MARK: - Public Methods
    
    /// Loads the initial set of assets
    func loadAssets() {
        guard authService.isAuthenticated else {
            errorMessage = "Not authenticated. Please check your credentials."
            return
        }
        
        isLoading = true
        errorMessage = nil
        nextPage = nil
        hasMoreAssets = true
        
        Task {
            do {
                let searchResult = try await assetProvider.fetchAssets(page: 1, limit: 30)
                
                self.assets = searchResult.assets
                self.nextPage = searchResult.nextPage
                self.isLoading = false
                self.hasMoreAssets = searchResult.nextPage != nil
                
                // Notify parent view about loaded assets
                onAssetsLoaded?(searchResult.assets)
                
                // Preload thumbnails for better performance
                ThumbnailCache.shared.preloadThumbnails(for: searchResult.assets)
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    /// Triggers debounced loading of more assets for infinite scroll
    func debouncedLoadMore() {
        guard !isLoadingMore && hasMoreAssets else { return }
        
        isLoadingMore = true
        
        // Cancel any existing load more task
        loadMoreTask?.cancel()
        
        // Create a new debounced task
        loadMoreTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
            
            if Task.isCancelled {
                isLoadingMore = false
                return
            }
            
            await loadMoreAssets()
        }
    }
    
    /// Handles deep link navigation to a specific asset
    func handleDeepLinkAsset(_ assetId: String) -> Bool {
        if let asset = assets.first(where: { $0.id == assetId }) {
            debugLog("AssetGridViewModel: Asset \(assetId) found in loaded assets")
            if let index = assets.firstIndex(of: asset) {
                currentAssetIndex = index
            }
            return true
        } else {
            debugLog("AssetGridViewModel: Asset \(assetId) not found in current loaded assets")
            if assets.isEmpty {
                loadAssets()
            }
            return false
        }
    }
    
    /// Selects an asset and updates the current index
    func selectAsset(_ asset: ImmichAsset) {
        debugLog("AssetGridViewModel: Asset selected: \(asset.id)")
        selectedAsset = asset
        if let index = assets.firstIndex(of: asset) {
            currentAssetIndex = index
            debugLog("AssetGridViewModel: Set currentAssetIndex to \(index)")
        }
    }
    
    /// Updates the current asset index when focus changes
    func updateCurrentIndex(for assetId: String) {
        if let asset = assets.first(where: { $0.id == assetId }),
           let index = assets.firstIndex(of: asset) {
            currentAssetIndex = index
            debugLog("AssetGridViewModel: Updated currentAssetIndex to \(index) for focused asset")
        }
    }
    
    /// Checks if more assets should be loaded based on current position
    func shouldLoadMore(for asset: ImmichAsset) -> Bool {
        guard let index = assets.firstIndex(of: asset) else { return false }
        let threshold = max(assets.count - 100, 0)
        return index >= threshold && hasMoreAssets && !isLoadingMore
    }
    
    /// Gets the starting asset ID for slideshow based on current position
    func getSlideshowStartingAssetId() -> String? {
        guard currentAssetIndex < assets.count else { 
            debugLog("AssetGridViewModel: getSlideshowStartingAssetId - currentAssetIndex \(currentAssetIndex) out of bounds, returning nil")
            return nil 
        }
        let currentAsset = assets[currentAssetIndex]
        debugLog("AssetGridViewModel: getSlideshowStartingAssetId - currentAssetIndex=\(currentAssetIndex), currentAsset=\(currentAsset.id)")
        return currentAsset.id
    }
    
    /// Cancels any pending load operations
    func cancelPendingLoads() {
        loadMoreTask?.cancel()
    }
    
    // MARK: - Private Methods
    
    private func loadMoreAssets() async {
        guard hasMoreAssets && nextPage != nil else {
            isLoadingMore = false
            return
        }
        
        do {
            let pageNumber = extractPageFromNextPage(nextPage!)
            let searchResult = try await assetProvider.fetchAssets(page: pageNumber, limit: 30)
            
            if !searchResult.assets.isEmpty {
                self.assets.append(contentsOf: searchResult.assets)
                self.nextPage = searchResult.nextPage
                self.hasMoreAssets = searchResult.nextPage != nil
            } else {
                self.hasMoreAssets = false
            }
            self.isLoadingMore = false
            
            // Preload thumbnails for newly loaded assets
            ThumbnailCache.shared.preloadThumbnails(for: searchResult.assets)
        } catch {
            debugLog("AssetGridViewModel: Failed to load more assets: \(error)")
            self.isLoadingMore = false
        }
    }
    
    private func extractPageFromNextPage(_ nextPageString: String) -> Int {
        // Try direct integer parsing first
        if let pageNumber = Int(nextPageString) {
            return pageNumber
        }
        
        // Try to extract from URL parameters
        if nextPageString.contains("page="),
           let url = URL(string: nextPageString),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let pageParam = components.queryItems?.first(where: { $0.name == "page" }),
           let pageNumber = Int(pageParam.value ?? "2") {
            return pageNumber
        }
        
        // Default fallback - calculate based on current assets count
        return (assets.count / 100) + 2
    }
}

