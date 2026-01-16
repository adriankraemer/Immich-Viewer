import Foundation
import SwiftUI
import UIKit
import Combine

/// Represents the direction for slide transitions
enum SlideDirection: CaseIterable {
    case left, right, up, down
    case diagonal_up_left, diagonal_up_right
    case diagonal_down_left, diagonal_down_right
    case zoom_out
    case fade_only
    
    func offset(for size: CGSize) -> CGSize {
        let w = size.width * 1.2
        let h = size.height * 1.2
        switch self {
        case .left: return CGSize(width: -w, height: 0)
        case .right: return CGSize(width: w, height: 0)
        case .up: return CGSize(width: 0, height: -h)
        case .down: return CGSize(width: 0, height: h)
        case .diagonal_up_left: return CGSize(width: -w, height: -h)
        case .diagonal_up_right: return CGSize(width: w, height: -h)
        case .diagonal_down_left: return CGSize(width: -w, height: h)
        case .diagonal_down_right: return CGSize(width: w, height: h)
        case .zoom_out: return CGSize.zero
        case .fade_only: return CGSize.zero
        }
    }
    
    var scale: CGFloat {
        switch self {
        case .zoom_out: return 0.1
        default: return 1.0
        }
    }
    
    var opacity: Double {
        switch self {
        case .zoom_out: return 0.0
        case .fade_only: return 0.0
        default: return 1.0
        }
    }
    
    /// Returns a random direction excluding fade_only (which is only used explicitly)
    static func random() -> SlideDirection {
        let movementDirections: [SlideDirection] = [
            .left, .right, .up, .down,
            .diagonal_up_left, .diagonal_up_right,
            .diagonal_down_left, .diagonal_down_right,
            .zoom_out
        ]
        return movementDirections.randomElement() ?? .right
    }
}

/// Data structure for a loaded image ready for display
struct SlideshowImageData: Equatable {
    let asset: ImmichAsset
    let image: UIImage
    
    static func == (lhs: SlideshowImageData, rhs: SlideshowImageData) -> Bool {
        lhs.asset.id == rhs.asset.id
    }
}

/// Settings for slideshow behavior loaded from UserDefaults
struct SlideshowConfiguration {
    var slideInterval: TimeInterval
    var backgroundColor: String
    var hideOverlay: Bool
    var enableReflections: Bool
    var enableKenBurns: Bool
    var enableFadeOnly: Bool
    var enableShuffle: Bool
    
    static func load() -> SlideshowConfiguration {
        SlideshowConfiguration(
            slideInterval: UserDefaults.standard.slideshowInterval,
            backgroundColor: UserDefaults.standard.slideshowBackgroundColor,
            hideOverlay: UserDefaults.standard.hideImageOverlay,
            enableReflections: UserDefaults.standard.enableReflectionsInSlideshow,
            enableKenBurns: UserDefaults.standard.enableKenBurnsEffect,
            enableFadeOnly: UserDefaults.standard.enableFadeOnlyEffect,
            enableShuffle: UserDefaults.standard.enableSlideshowShuffle
        )
    }
    
    mutating func reload() {
        slideInterval = UserDefaults.standard.slideshowInterval
        backgroundColor = UserDefaults.standard.slideshowBackgroundColor
        hideOverlay = UserDefaults.standard.hideImageOverlay
        enableReflections = UserDefaults.standard.enableReflectionsInSlideshow
        enableKenBurns = UserDefaults.standard.enableKenBurnsEffect
        enableFadeOnly = UserDefaults.standard.enableFadeOnlyEffect
        enableShuffle = UserDefaults.standard.enableSlideshowShuffle
    }
    
    var dimensionMultiplier: Double {
        enableReflections ? 0.9 : 1.0
    }
}

@MainActor
class SlideshowViewModel: ObservableObject {
    // MARK: - Published Properties (View State)
    @Published var currentImageData: SlideshowImageData?
    @Published var isLoading = true
    @Published var isTransitioning = false
    @Published var slideDirection: SlideDirection = .right
    @Published var settings: SlideshowConfiguration
    @Published var isPaused = false
    
    // Ken Burns effect state
    @Published var kenBurnsScale: CGFloat = 1.0
    @Published var kenBurnsOffset: CGSize = .zero
    
    // MARK: - Internal State
    private var imageQueue: [SlideshowImageData] = []
    private var assetQueue: [ImmichAsset] = []
    private var isLoadingAssets = false
    private var hasMoreAssets = true
    private var currentPage = 1
    private var isSharedAlbum = false
    
    // MARK: - Dependencies
    private let assetService: AssetService
    private let albumService: AlbumService?
    private var assetProvider: AssetProvider?
    
    // MARK: - Configuration
    private let albumId: String?
    private let personId: String?
    private let tagId: String?
    private let city: String?
    private let countryName: String?
    private let folderPath: String?
    private let startingAssetId: String?
    private let isFavorite: Bool
    private let isAllPhotos: Bool
    private let exploreService: ExploreService?
    
    // MARK: - Tasks & Timers
    private var loadAssetsTask: Task<Void, Never>?
    private var autoAdvanceTimer: Timer?
    
    // MARK: - Constants
    let slideAnimationDuration: Double = 1.5
    
    // MARK: - Computed Properties
    var currentAsset: ImmichAsset? {
        currentImageData?.asset
    }
    
    var effectiveBackgroundColor: Color {
        getBackgroundColor(settings.backgroundColor)
    }
    
    var queueSize: Int {
        imageQueue.count
    }
    
    // MARK: - Initialization
    init(
        assetService: AssetService,
        albumService: AlbumService?,
        albumId: String? = nil,
        personId: String? = nil,
        tagId: String? = nil,
        city: String? = nil,
        countryName: String? = nil,
        folderPath: String? = nil,
        startingAssetId: String? = nil,
        isFavorite: Bool = false,
        isAllPhotos: Bool = false,
        exploreService: ExploreService? = nil
    ) {
        self.assetService = assetService
        self.albumService = albumService
        self.albumId = albumId
        self.personId = personId
        self.tagId = tagId
        self.city = city
        self.countryName = countryName
        self.folderPath = folderPath
        self.startingAssetId = startingAssetId
        self.isFavorite = isFavorite
        self.isAllPhotos = isAllPhotos
        self.exploreService = exploreService
        self.settings = SlideshowConfiguration.load()
        
        // Create asset provider
        self.assetProvider = AssetProviderFactory.createProvider(
            albumId: albumId,
            personId: personId,
            tagId: tagId,
            city: city,
            countryName: countryName,
            isAllPhotos: isAllPhotos,
            isFavorite: isFavorite,
            folderPath: folderPath,
            assetService: assetService,
            albumService: albumService,
            exploreService: exploreService
        )
    }
    
    // MARK: - Public Methods
    
    /// Initializes and starts the slideshow
    func startSlideshow() {
        loadAssetsTask = Task {
            await checkIfAlbumIsShared()
            await loadInitialAssets()
            await loadInitialImages()
            await showFirstImage()
        }
    }
    
    /// Cleans up resources when slideshow ends
    func cleanup() {
        loadAssetsTask?.cancel()
        loadAssetsTask = nil
        stopAutoAdvance()
        
        currentImageData = nil
        imageQueue.removeAll()
        assetQueue.removeAll()
        
        // Restart auto-slideshow timer when slideshow ends
        NotificationCenter.default.post(name: NSNotification.Name("restartAutoSlideshowTimer"), object: nil)
    }
    
    /// Advances to the next image in the slideshow
    func nextImage() {
        debugLog("SlideshowViewModel: nextImage() called")
        
        guard !imageQueue.isEmpty else {
            debugLog("SlideshowViewModel: No more images in queue")
            return
        }
        
        debugLog("SlideshowViewModel: Starting slide out animation")
        
        // Set slide direction before transition starts
        // Use fade_only direction when fade only effect is enabled
        if settings.enableFadeOnly {
            slideDirection = .fade_only
        } else {
            slideDirection = SlideDirection.random()
        }
        
        withAnimation(.easeInOut(duration: slideAnimationDuration)) {
            isTransitioning = true
        }
        
        // Wait for slide out to complete, then change image
        DispatchQueue.main.asyncAfter(deadline: .now() + slideAnimationDuration) { [weak self] in
            guard let self = self else { return }
            
            // Discard current image to free memory
            self.currentImageData = nil
            
            guard !self.imageQueue.isEmpty else {
                debugLog("SlideshowViewModel: No more images in queue to advance")
                return
            }
            
            self.currentImageData = self.imageQueue.removeFirst()
            
            withAnimation(.easeInOut(duration: self.slideAnimationDuration)) {
                self.isTransitioning = false
            }
            
            self.startKenBurnsEffect()
            self.startAutoAdvance()
            
            Task {
                await self.maintainImageQueue()
            }
            
            debugLog("SlideshowViewModel: Advanced to next image, queue size: \(self.imageQueue.count)")
        }
    }
    
    /// Toggles pause/resume state of the slideshow
    func togglePause() {
        if isPaused {
            resume()
        } else {
            pause()
        }
    }
    
    /// Pauses the slideshow
    func pause() {
        isPaused = true
        stopAutoAdvance()
        debugLog("SlideshowViewModel: Slideshow paused")
    }
    
    /// Resumes the slideshow
    func resume() {
        isPaused = false
        startAutoAdvance()
        debugLog("SlideshowViewModel: Slideshow resumed")
    }
    
    /// Reloads settings from UserDefaults
    func reloadSettings() {
        settings.reload()
    }
    
    // MARK: - Ken Burns Effect
    
    func startKenBurnsEffect() {
        guard settings.enableKenBurns else {
            kenBurnsScale = 1.0
            kenBurnsOffset = .zero
            return
        }
        
        let shouldZoomIn = Bool.random()
        let startScale: CGFloat = shouldZoomIn ? 1.0 : 1.2
        let endScale: CGFloat = shouldZoomIn ? 1.2 : 1.0
        
        let maxOffset: CGFloat = 20
        let startOffset = CGSize(
            width: CGFloat.random(in: -maxOffset...maxOffset),
            height: CGFloat.random(in: -maxOffset...maxOffset)
        )
        let endOffset = CGSize(
            width: CGFloat.random(in: -maxOffset...maxOffset),
            height: CGFloat.random(in: -maxOffset...maxOffset)
        )
        
        kenBurnsScale = startScale
        kenBurnsOffset = startOffset
        
        withAnimation(.linear(duration: settings.slideInterval)) {
            kenBurnsScale = endScale
            kenBurnsOffset = endOffset
        }
    }
    
    // MARK: - Private Methods
    
    private func checkIfAlbumIsShared() async {
        guard let albumId = albumId, let albumService = albumService else { return }
        
        do {
            let album = try await albumService.getAlbumInfo(albumId: albumId, withoutAssets: true)
            debugLog("SlideshowViewModel: Album info - shared: \(album.shared)")
            isSharedAlbum = album.shared
        } catch {
            debugLog("SlideshowViewModel: Failed to get album info: \(error)")
            isSharedAlbum = false
        }
    }
    
    private func loadInitialAssets() async {
        guard !Task.isCancelled, let assetProvider = assetProvider else { return }
        
        do {
            if settings.enableShuffle && !isSharedAlbum {
                // Shuffle mode: fetch random assets
                let searchResult = try await assetProvider.fetchRandomAssets(limit: 100)
                let imageAssets = searchResult.assets.filter { $0.type == .image }
                assetQueue = imageAssets
                hasMoreAssets = true // Always more random assets available
                debugLog("SlideshowViewModel: Loaded \(imageAssets.count) random assets")
            } else {
                // Sequential mode: find the starting asset by searching through pages
                debugLog("SlideshowViewModel: Looking for starting asset: \(startingAssetId ?? "none")")
                
                var foundStartingAsset = false
                var allImageAssets: [ImmichAsset] = []
                var page = 1
                let pageSize = 100
                
                // Keep fetching pages until we find the starting asset or run out of assets
                while !foundStartingAsset {
                    let result = try await assetProvider.fetchAssets(page: page, limit: pageSize)
                    let imageAssets = result.assets.filter { $0.type == .image }
                    
                    debugLog("SlideshowViewModel: Fetched page \(page) with \(imageAssets.count) images")
                    
                    // Check if starting asset is in this batch
                    if let targetId = startingAssetId,
                       let targetIndex = imageAssets.firstIndex(where: { $0.id == targetId }) {
                        // Found it! Start from this asset
                        assetQueue = Array(imageAssets.dropFirst(targetIndex))
                        currentPage = page
                        hasMoreAssets = result.nextPage != nil
                        foundStartingAsset = true
                        debugLog("SlideshowViewModel: Found starting asset \(targetId) at index \(targetIndex) on page \(page)")
                    } else if result.nextPage == nil {
                        // No more pages, use what we have from page 1
                        if allImageAssets.isEmpty {
                            allImageAssets = imageAssets
                        }
                        assetQueue = allImageAssets
                        currentPage = 1
                        hasMoreAssets = false
                        foundStartingAsset = true
                        debugLog("SlideshowViewModel: Starting asset not found, starting from beginning")
                    } else if page == 1 {
                        // Save first page in case we need to fall back
                        allImageAssets = imageAssets
                        page += 1
                    } else {
                        page += 1
                    }
                    
                    // Safety limit to prevent infinite loops
                    if page > 100 {
                        assetQueue = allImageAssets
                        currentPage = 1
                        hasMoreAssets = true
                        debugLog("SlideshowViewModel: Hit page limit, starting from beginning")
                        break
                    }
                }
                
                if let firstQueueAsset = assetQueue.first {
                    debugLog("SlideshowViewModel: First asset in queue: \(firstQueueAsset.id)")
                }
                debugLog("SlideshowViewModel: Queue size: \(assetQueue.count)")
            }
        } catch {
            debugLog("SlideshowViewModel: Failed to load initial assets: \(error)")
            isLoading = false
        }
    }
    
    private func loadInitialImages() async {
        guard !assetQueue.isEmpty else {
            isLoading = false
            return
        }
        
        let imagesToLoad = min(3, assetQueue.count)
        for i in 0..<imagesToLoad {
            guard i < assetQueue.count else { break }
            await loadImageIntoQueue(asset: assetQueue[i])
        }
        
        assetQueue.removeFirst(min(imagesToLoad, assetQueue.count))
    }
    
    private func loadImageIntoQueue(asset: ImmichAsset) async {
        guard !Task.isCancelled else { return }
        
        do {
            guard let image = try await assetService.loadFullImage(asset: asset) else {
                debugLog("SlideshowViewModel: loadFullImage returned nil for asset \(asset.id)")
                return
            }
            
            let imageData = SlideshowImageData(asset: asset, image: image)
            imageQueue.append(imageData)
            debugLog("SlideshowViewModel: Loaded image for asset \(asset.id) into queue")
        } catch {
            debugLog("SlideshowViewModel: Failed to load image for asset \(asset.id): \(error)")
        }
    }
    
    private func showFirstImage() async {
        guard !imageQueue.isEmpty else {
            isLoading = false
            return
        }
        
        currentImageData = imageQueue.removeFirst()
        isLoading = false
        
        startKenBurnsEffect()
        startAutoAdvance()
        
        Task {
            await maintainImageQueue()
        }
    }
    
    private func maintainImageQueue() async {
        if imageQueue.count < 2 {
            await loadMoreImagesIfNeeded()
        }
    }
    
    private func loadMoreImagesIfNeeded() async {
        let shouldLoadAssets = assetQueue.count <= 2 && hasMoreAssets && !isLoadingAssets
        
        if shouldLoadAssets {
            await loadMoreAssets()
        }
        
        let assetsToLoad = Array(assetQueue.prefix(min(2, assetQueue.count)))
        
        for asset in assetsToLoad {
            await loadImageIntoQueue(asset: asset)
        }
        
        assetQueue.removeFirst(min(assetsToLoad.count, assetQueue.count))
    }
    
    private func loadMoreAssets() async {
        guard !isLoadingAssets && hasMoreAssets, let assetProvider = assetProvider else {
            debugLog("SlideshowViewModel: Skipping asset load - already loading or no more assets")
            return
        }
        
        isLoadingAssets = true
        
        do {
            let searchResult: SearchResult
            if settings.enableShuffle && !isSharedAlbum {
                searchResult = try await assetProvider.fetchRandomAssets(limit: 100)
            } else {
                currentPage += 1
                searchResult = try await assetProvider.fetchAssets(page: currentPage, limit: 100)
            }
            
            let imageAssets = searchResult.assets.filter { $0.type == .image }
            assetQueue.append(contentsOf: imageAssets)
            hasMoreAssets = searchResult.nextPage != nil || (settings.enableShuffle && !isSharedAlbum)
            isLoadingAssets = false
            debugLog("SlideshowViewModel: Loaded \(imageAssets.count) more assets, total queue: \(assetQueue.count)")
        } catch {
            debugLog("SlideshowViewModel: Failed to load more assets: \(error)")
            isLoadingAssets = false
            hasMoreAssets = settings.enableShuffle && !isSharedAlbum
        }
    }
    
    private func startAutoAdvance() {
        stopAutoAdvance()
        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: settings.slideInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                debugLog("SlideshowViewModel: Timer fired - queue size: \(self.imageQueue.count)")
                self.nextImage()
            }
        }
    }
    
    private func stopAutoAdvance() {
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = nil
    }
}

// MARK: - Image Size Calculation Helper

extension SlideshowViewModel {
    /// Calculates the actual displayed size of an image within a container using .fit aspect ratio
    func calculateActualImageSize(imageSize: CGSize, containerSize: CGSize) -> CGSize {
        let imageAspectRatio = imageSize.width / imageSize.height
        let containerAspectRatio = containerSize.width / containerSize.height
        
        if imageAspectRatio > containerAspectRatio {
            let actualWidth = containerSize.width
            let actualHeight = actualWidth / imageAspectRatio
            return CGSize(width: actualWidth, height: actualHeight)
        } else {
            let actualHeight = containerSize.height
            let actualWidth = actualHeight * imageAspectRatio
            return CGSize(width: actualWidth, height: actualHeight)
        }
    }
}

