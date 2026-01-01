//
//  WorldMapViewModel.swift
//  Immich Gallery
//
//  ViewModel for WorldMap feature following MVVM pattern
//

import Foundation
import SwiftUI
import MapKit
import Combine

enum PanDirection {
    case up
    case down
    case left
    case right
}

/// Loading state for progressive map data loading
enum MapLoadingState: Equatable {
    case idle
    case loadingMarkers      // Initial fast load of lightweight markers
    case loadingDetails      // Loading full asset details for visible region
    case ready
    case error(String)
    
    static func == (lhs: MapLoadingState, rhs: MapLoadingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loadingMarkers, .loadingMarkers),
             (.loadingDetails, .loadingDetails), (.ready, .ready):
            return true
        case (.error(let lhsMsg), .error(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

@MainActor
class WorldMapViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var clusters: [PhotoCluster] = []
    @Published var loadingState: MapLoadingState = .idle
    @Published var errorMessage: String?
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20.0, longitude: 0.0),
        span: MKCoordinateSpan(latitudeDelta: 100.0, longitudeDelta: 100.0)
    )
    @Published var selectedCluster: PhotoCluster?
    @Published var loadingProgress: String = ""
    
    /// Computed property for backward compatibility
    var isLoading: Bool {
        switch loadingState {
        case .loadingMarkers, .loadingDetails:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Private Properties
    
    /// Spatial index for efficient marker lookups
    private let spatialIndex = SpatialMarkerIndex()
    
    /// Lightweight clusters for fast initial rendering
    private var lightweightClusters: [LightweightCluster] = []
    
    /// Cache of loaded assets by ID for detail views
    private var assetCache: [String: ImmichAsset] = [:]
    
    /// All clusters with full data (populated progressively)
    private var allClusters: [PhotoCluster] = []
    
    /// All assets with location data (for re-clustering at different zoom levels)
    private var allAssets: [ImmichAsset] = []
    
    /// Whether we're in overview mode (showing all clusters) or zoomed mode (filtered)
    private var isOverviewMode: Bool = true
    
    /// Whether we're currently loading initial data (to prevent region updates during load)
    private var isInitialLoad: Bool = false
    
    /// Threshold span to determine if we're in overview mode
    /// If span is larger than this, show all clusters; otherwise filter by region
    private let overviewModeThreshold: Double = 50.0 // degrees
    
    /// Minimum cluster radius in meters (100km as per requirement)
    private let minimumClusterRadius: Double = 100_000
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Task for loading details (can be cancelled when region changes)
    private var detailLoadingTask: Task<Void, Never>?
    
    /// Currently loaded region (to avoid redundant loads)
    private var loadedRegion: MKCoordinateRegion?
    
    // MARK: - Dependencies
    private let mapService: MapService
    private let assetService: AssetService
    
    // MARK: - Initialization
    init(mapService: MapService, assetService: AssetService) {
        self.mapService = mapService
        self.assetService = assetService
        
        // Watch for region changes to update visible clusters
        $region
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] newRegion in
                Task { @MainActor [weak self] in
                    guard let self = self, !self.isInitialLoad else { return }
                    await self.handleRegionChange(newRegion)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Loads map data progressively - first lightweight markers, then details on demand
    func loadMapData() async {
        guard loadingState != .loadingMarkers else { return }
        
        loadingState = .loadingMarkers
        isInitialLoad = true
        errorMessage = nil
        loadingProgress = "Loading location data..."
        
        do {
            // Phase 1: Load lightweight markers (fast)
            let markers = try await mapService.fetchMapMarkers()
            
            guard !markers.isEmpty else {
                loadingState = .ready
                isInitialLoad = false
                loadingProgress = ""
                return
            }
            
            loadingProgress = "Indexing \(markers.count) locations..."
            
            // Index markers for fast spatial queries
            spatialIndex.index(markers: markers)
            
            // Phase 2: Create lightweight clusters with 100km minimum radius
            loadingProgress = "Clustering locations..."
            lightweightClusters = MapClusterer.clusterMarkers(markers, clusterRadius: minimumClusterRadius)
            
            // Convert to PhotoClusters with placeholder assets for display
            clusters = lightweightClusters.map { lightweight in
                // Create minimal placeholder assets for initial display
                let placeholderAssets = lightweight.markerIds.prefix(5).map { markerId in
                    createPlaceholderAsset(id: markerId, cluster: lightweight)
                }
                return PhotoCluster(from: lightweight, assets: placeholderAssets)
            }
            
            allClusters = clusters
            isOverviewMode = true
            
            // Update map region to show all clusters
            if !clusters.isEmpty {
                updateRegionToFitClusters()
            }
            
            loadingState = .ready
            isInitialLoad = false
            loadingProgress = ""
            
            print("WorldMapViewModel: Loaded \(markers.count) markers into \(clusters.count) clusters")
            
        } catch {
            errorMessage = error.localizedDescription
            loadingState = .error(error.localizedDescription)
            isInitialLoad = false
            loadingProgress = ""
        }
    }
    
    /// Loads full asset data using the legacy method (for compatibility)
    func loadFullMapData() async {
        guard loadingState != .loadingMarkers else { return }
        
        loadingState = .loadingMarkers
        isInitialLoad = true
        errorMessage = nil
        loadingProgress = "Loading all photo data..."
        
        do {
            let assets = try await mapService.fetchGeodata()
            allAssets = assets
            
            loadingProgress = "Clustering \(assets.count) photos..."
            
            // Initial clustering with 100km minimum radius for overview
            let photoClusters = MapClusterer.clusterPhotos(assets, clusterRadius: minimumClusterRadius)
            allClusters = photoClusters
            clusters = photoClusters
            isOverviewMode = true
            
            // Update map region to show all clusters
            if !clusters.isEmpty {
                updateRegionToFitClusters()
            }
            
            loadingState = .ready
            isInitialLoad = false
            loadingProgress = ""
        } catch {
            errorMessage = error.localizedDescription
            loadingState = .error(error.localizedDescription)
            isInitialLoad = false
            loadingProgress = ""
        }
    }
    
    func refresh() async {
        mapService.invalidateCache()
        assetCache.removeAll()
        loadedRegion = nil
        await loadMapData()
    }
    
    func selectCluster(_ cluster: PhotoCluster) {
        selectedCluster = cluster
    }
    
    // MARK: - Map Navigation Methods
    func zoomIn() {
        let currentSpan = region.span
        let newLatDelta = max(currentSpan.latitudeDelta * 0.7, 0.1)
        let newLonDelta = max(currentSpan.longitudeDelta * 0.7, 0.1)
        
        region = MKCoordinateRegion(
            center: region.center,
            span: MKCoordinateSpan(latitudeDelta: newLatDelta, longitudeDelta: newLonDelta)
        )
    }
    
    func zoomOut() {
        let currentSpan = region.span
        let newLatDelta = min(currentSpan.latitudeDelta * 2.0, 90.0)
        let newLonDelta = min(currentSpan.longitudeDelta * 2.0, 180.0)
        
        region = MKCoordinateRegion(
            center: region.center,
            span: MKCoordinateSpan(latitudeDelta: newLatDelta, longitudeDelta: newLonDelta)
        )
    }
    
    func pan(direction: PanDirection) {
        let currentSpan = region.span
        let latOffset = currentSpan.latitudeDelta * 0.3
        let lonOffset = currentSpan.longitudeDelta * 0.3
        
        var newCenter = region.center
        
        switch direction {
        case .up:
            newCenter.latitude = min(newCenter.latitude + latOffset, 85.0)
        case .down:
            newCenter.latitude = max(newCenter.latitude - latOffset, -85.0)
        case .left:
            newCenter.longitude = newCenter.longitude - lonOffset
            if newCenter.longitude < -180 {
                newCenter.longitude += 360
            }
        case .right:
            newCenter.longitude = newCenter.longitude + lonOffset
            if newCenter.longitude > 180 {
                newCenter.longitude -= 360
            }
        }
        
        region = MKCoordinateRegion(
            center: newCenter,
            span: currentSpan
        )
    }
    
    // MARK: - Private Methods
    
    /// Handles region changes - updates clusters and loads details as needed
    private func handleRegionChange(_ newRegion: MKCoordinateRegion) async {
        // Cancel any pending detail loading
        detailLoadingTask?.cancel()
        
        let currentSpan = newRegion.span
        let isNowOverviewMode = currentSpan.latitudeDelta >= overviewModeThreshold ||
                                currentSpan.longitudeDelta >= overviewModeThreshold
        
        // If we're in overview mode, show all clusters
        if isNowOverviewMode {
            if !isOverviewMode {
                clusters = allClusters
                isOverviewMode = true
            }
            return
        }
        
        // We're zoomed in - update clusters based on visible region
        isOverviewMode = false
        
        // Use spatial index for fast marker lookup
        if !spatialIndex.isEmpty {
            await updateClustersFromMarkers(in: newRegion)
        } else if !allAssets.isEmpty {
            await updateClustersFromAssets(in: newRegion)
        }
    }
    
    /// Updates clusters from lightweight markers (fast path)
    private func updateClustersFromMarkers(in region: MKCoordinateRegion) async {
        let visibleMarkers = spatialIndex.markers(in: region)
        
        // Calculate appropriate cluster radius for zoom level
        let clusterRadius = MapClusterer.calculateClusterRadius(for: region.span)
        
        // Re-cluster visible markers
        let visibleLightweightClusters = MapClusterer.clusterMarkers(visibleMarkers, clusterRadius: clusterRadius)
        
        // Convert to PhotoClusters
        clusters = visibleLightweightClusters.map { lightweight in
            // Check cache for any loaded assets
            let cachedAssets = lightweight.markerIds.compactMap { assetCache[$0] }
            
            if !cachedAssets.isEmpty {
                return PhotoCluster(from: lightweight, assets: cachedAssets)
            } else {
                // Use placeholder assets
                let placeholderAssets = lightweight.markerIds.prefix(5).map { markerId in
                    createPlaceholderAsset(id: markerId, cluster: lightweight)
                }
                return PhotoCluster(from: lightweight, assets: placeholderAssets)
            }
        }
        
        // Optionally load full asset details in background for zoomed-in views
        if region.span.latitudeDelta < 10.0 && region.span.longitudeDelta < 10.0 {
            detailLoadingTask = Task {
                await loadDetailsForVisibleClusters(visibleLightweightClusters)
            }
        }
    }
    
    /// Updates clusters from full assets (fallback path)
    private func updateClustersFromAssets(in region: MKCoordinateRegion) async {
        let visibleBounds = calculateVisibleBounds(for: region)
        
        let visibleAssets = allAssets.filter { asset in
            guard let exifInfo = asset.exifInfo,
                  let latitude = exifInfo.latitude,
                  let longitude = exifInfo.longitude else {
                return false
            }
            return isCoordinateInBounds(
                CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                bounds: visibleBounds
            )
        }
        
        let clusterRadius = MapClusterer.calculateClusterRadius(for: region.span)
        clusters = MapClusterer.clusterPhotos(visibleAssets, clusterRadius: clusterRadius)
    }
    
    /// Loads full asset details for visible clusters (background task)
    private func loadDetailsForVisibleClusters(_ lightweightClusters: [LightweightCluster]) async {
        // Collect IDs that need loading (not in cache)
        var idsToLoad: [String] = []
        for cluster in lightweightClusters {
            for markerId in cluster.markerIds {
                if assetCache[markerId] == nil && !idsToLoad.contains(markerId) {
                    idsToLoad.append(markerId)
                }
            }
        }
        
        guard !idsToLoad.isEmpty else { return }
        
        // Limit to reasonable batch size
        let limitedIds = Array(idsToLoad.prefix(200))
        
        do {
            loadingState = .loadingDetails
            
            let assets = try await mapService.fetchAssetsById(ids: limitedIds)
            
            // Check for cancellation
            try Task.checkCancellation()
            
            // Update cache
            for asset in assets {
                assetCache[asset.id] = asset
            }
            
            // Update clusters with loaded assets
            clusters = lightweightClusters.map { lightweight in
                let loadedAssets = lightweight.markerIds.compactMap { assetCache[$0] }
                if !loadedAssets.isEmpty {
                    return PhotoCluster(from: lightweight, assets: loadedAssets)
                } else {
                    let placeholderAssets = lightweight.markerIds.prefix(5).map { markerId in
                        createPlaceholderAsset(id: markerId, cluster: lightweight)
                    }
                    return PhotoCluster(from: lightweight, assets: placeholderAssets)
                }
            }
            
            loadingState = .ready
            
        } catch is CancellationError {
            // Task was cancelled - this is expected when region changes
            loadingState = .ready
        } catch {
            print("WorldMapViewModel: Failed to load asset details: \(error)")
            loadingState = .ready
        }
    }
    
    /// Creates a placeholder asset for initial display before full data is loaded
    private func createPlaceholderAsset(id: String, cluster: LightweightCluster) -> ImmichAsset {
        let exifInfo = ExifInfo(
            make: nil,
            model: nil,
            imageName: nil,
            exifImageWidth: nil,
            exifImageHeight: nil,
            dateTimeOriginal: nil,
            modifyDate: nil,
            lensModel: nil,
            fNumber: nil,
            focalLength: nil,
            iso: nil,
            exposureTime: nil,
            latitude: cluster.coordinate.latitude,
            longitude: cluster.coordinate.longitude,
            city: cluster.city,
            state: cluster.state,
            country: cluster.country,
            timeZone: nil,
            description: nil,
            fileSizeInByte: nil,
            orientation: nil,
            projectionType: nil,
            rating: nil
        )
        
        return ImmichAsset(
            id: id,
            deviceAssetId: id,
            deviceId: "",
            ownerId: "",
            libraryId: nil,
            type: .image,
            originalPath: "",
            originalFileName: "",
            originalMimeType: nil,
            resized: nil,
            thumbhash: nil,
            fileModifiedAt: "",
            fileCreatedAt: "",
            localDateTime: "",
            updatedAt: "",
            isFavorite: false,
            isArchived: false,
            isOffline: false,
            isTrashed: false,
            checksum: "",
            duration: nil,
            hasMetadata: true,
            livePhotoVideoId: nil,
            people: [],
            visibility: "timeline",
            duplicateId: nil,
            exifInfo: exifInfo
        )
    }
    
    /// Calculates the visible bounds of the current map region
    private func calculateVisibleBounds(for region: MKCoordinateRegion) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        let center = region.center
        let span = region.span
        
        let minLat = center.latitude - span.latitudeDelta / 2
        let maxLat = center.latitude + span.latitudeDelta / 2
        let minLon = center.longitude - span.longitudeDelta / 2
        let maxLon = center.longitude + span.longitudeDelta / 2
        
        return (minLat, maxLat, minLon, maxLon)
    }
    
    /// Checks if a coordinate is within the given bounds
    private func isCoordinateInBounds(_ coordinate: CLLocationCoordinate2D, bounds: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)) -> Bool {
        var lon = coordinate.longitude
        if lon < -180 {
            lon += 360
        } else if lon > 180 {
            lon -= 360
        }
        
        var minLon = bounds.minLon
        var maxLon = bounds.maxLon
        
        if minLon < -180 {
            minLon += 360
        } else if minLon > 180 {
            minLon -= 360
        }
        
        if maxLon < -180 {
            maxLon += 360
        } else if maxLon > 180 {
            maxLon -= 360
        }
        
        let latInBounds = coordinate.latitude >= bounds.minLat && coordinate.latitude <= bounds.maxLat
        
        let lonInBounds: Bool
        if minLon > maxLon {
            lonInBounds = lon >= minLon || lon <= maxLon
        } else {
            lonInBounds = lon >= minLon && lon <= maxLon
        }
        
        return latInBounds && lonInBounds
    }
    
    func updateRegionToFitClusters() {
        guard !clusters.isEmpty else {
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 20.0, longitude: 0.0),
                span: MKCoordinateSpan(latitudeDelta: 100.0, longitudeDelta: 180.0)
            )
            return
        }
        
        let latitudes = clusters.map { $0.coordinate.latitude }
        let longitudes = clusters.map { $0.coordinate.longitude }
        
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        
        var latDelta = (maxLat - minLat) * 1.5
        var lonDelta = (maxLon - minLon) * 1.5
        
        latDelta = max(latDelta, 100.0)
        lonDelta = max(lonDelta, 180.0)
        
        let maxLatDelta: Double = 90.0
        let maxLonDelta: Double = 180.0
        
        latDelta = min(latDelta, maxLatDelta)
        lonDelta = min(lonDelta, maxLonDelta)
        
        if latDelta >= maxLatDelta * 0.8 || lonDelta >= maxLonDelta * 0.8 {
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 20.0, longitude: 0.0),
                span: MKCoordinateSpan(latitudeDelta: 100.0, longitudeDelta: 180.0)
            )
        } else {
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: MKCoordinateSpan(latitudeDelta: max(latDelta, 100.0), longitudeDelta: max(lonDelta, 180.0))
            )
        }
    }
}

