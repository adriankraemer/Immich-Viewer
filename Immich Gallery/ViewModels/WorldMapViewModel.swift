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

@MainActor
class WorldMapViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var clusters: [PhotoCluster] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20.0, longitude: 0.0),
        span: MKCoordinateSpan(latitudeDelta: 100.0, longitudeDelta: 100.0)
    )
    @Published var selectedCluster: PhotoCluster?
    
    // MARK: - Private Properties
    /// All clusters loaded from the server (never filtered)
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
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
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
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    // Don't update during initial load
                    guard let self = self, !self.isInitialLoad else { return }
                    await self.updateVisibleClusters()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func loadMapData() async {
        guard !isLoading else { return }
        
        isLoading = true
        isInitialLoad = true
        errorMessage = nil
        
        do {
            let assets = try await mapService.fetchGeodata()
            allAssets = assets
            
            // Initial clustering with default radius for overview
            let photoClusters = MapClusterer.clusterPhotos(assets, clusterRadius: 50000)
            allClusters = photoClusters
            clusters = photoClusters
            isOverviewMode = true
            
            // Update map region to show all clusters
            if !clusters.isEmpty {
                updateRegionToFitClusters()
            }
            
            isLoading = false
            isInitialLoad = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            isInitialLoad = false
        }
    }
    
    func refresh() async {
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
        
        // Update clusters when zooming in (will be handled by region change observer)
    }
    
    func zoomOut() {
        let currentSpan = region.span
        let newLatDelta = min(currentSpan.latitudeDelta * 1.3, 90.0)
        let newLonDelta = min(currentSpan.longitudeDelta * 1.3, 180.0)
        
        region = MKCoordinateRegion(
            center: region.center,
            span: MKCoordinateSpan(latitudeDelta: newLatDelta, longitudeDelta: newLonDelta)
        )
        
        // Update clusters when zooming out (will be handled by region change observer)
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
            // Handle longitude wrapping
            if newCenter.longitude < -180 {
                newCenter.longitude += 360
            }
        case .right:
            newCenter.longitude = newCenter.longitude + lonOffset
            // Handle longitude wrapping
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
    
    /// Updates visible clusters based on current region and zoom level
    private func updateVisibleClusters() async {
        guard !allClusters.isEmpty else { return }
        
        let currentSpan = region.span
        let isNowOverviewMode = currentSpan.latitudeDelta >= overviewModeThreshold || 
                                currentSpan.longitudeDelta >= overviewModeThreshold
        
        // If we're in overview mode, show all clusters
        if isNowOverviewMode {
            if !isOverviewMode {
                // Switching back to overview - use original clusters
                clusters = allClusters
                isOverviewMode = true
            }
            return
        }
        
        // We're zoomed in - filter clusters by visible region and potentially re-cluster
        isOverviewMode = false
        
        // Calculate visible bounds
        let visibleBounds = calculateVisibleBounds()
        
        // Filter assets that are within visible region
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
        
        // Determine cluster radius based on zoom level
        // Smaller span = more zoomed in = smaller cluster radius
        let clusterRadius = calculateClusterRadius(for: currentSpan)
        
        // Re-cluster visible assets with appropriate radius
        let visibleClusters = MapClusterer.clusterPhotos(visibleAssets, clusterRadius: clusterRadius)
        clusters = visibleClusters
    }
    
    /// Calculates the cluster radius based on current zoom level
    private func calculateClusterRadius(for span: MKCoordinateSpan) -> Double {
        // Use the average of lat/lon delta to determine zoom level
        let avgSpan = (span.latitudeDelta + span.longitudeDelta) / 2
        
        // Convert degrees to approximate meters (1 degree ≈ 111km at equator)
        let spanInMeters = avgSpan * 111000
        
        // Cluster radius should be proportional to visible area
        // At high zoom (small span), use smaller radius (e.g., 1-5km)
        // At medium zoom, use medium radius (e.g., 10-20km)
        // At low zoom (large span), use larger radius (e.g., 50km+)
        
        if avgSpan < 1.0 {
            // Very zoomed in - use small clusters (1-2km)
            return 2000
        } else if avgSpan < 5.0 {
            // Medium zoom - use medium clusters (5-10km)
            return 10000
        } else if avgSpan < 20.0 {
            // Low zoom - use larger clusters (20-30km)
            return 30000
        } else {
            // Very low zoom - use large clusters (50km)
            return 50000
        }
    }
    
    /// Calculates the visible bounds of the current map region
    private func calculateVisibleBounds() -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
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
        // Handle longitude wrapping
        var lon = coordinate.longitude
        if lon < -180 {
            lon += 360
        } else if lon > 180 {
            lon -= 360
        }
        
        // Normalize bounds for longitude wrapping
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
        
        // Check if coordinate is in bounds
        let latInBounds = coordinate.latitude >= bounds.minLat && coordinate.latitude <= bounds.maxLat
        
        // Handle longitude wrapping case
        let lonInBounds: Bool
        if minLon > maxLon {
            // Wraps around the date line
            lonInBounds = lon >= minLon || lon <= maxLon
        } else {
            lonInBounds = lon >= minLon && lon <= maxLon
        }
        
        return latInBounds && lonInBounds
    }
    
    func updateRegionToFitClusters() {
        guard !clusters.isEmpty else {
            // Default world view if no clusters
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
        
        // Calculate span with padding to show all clusters
        var latDelta = (maxLat - minLat) * 1.5
        var lonDelta = (maxLon - minLon) * 1.5
        
        // Ensure minimum span values - use larger defaults to show more of the world
        latDelta = max(latDelta, 100.0)  // Show more of the world by default
        lonDelta = max(lonDelta, 180.0)   // Show entire world width
        
        // Clamp to MapKit's maximum valid values
        let maxLatDelta: Double = 90.0   // Half the globe
        let maxLonDelta: Double = 180.0  // Half the globe
        
        latDelta = min(latDelta, maxLatDelta)
        lonDelta = min(lonDelta, maxLonDelta)
        
        // Always use a world view that shows everything
        // If clusters span a large area, use full world view
        if latDelta >= maxLatDelta * 0.8 || lonDelta >= maxLonDelta * 0.8 {
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 20.0, longitude: 0.0),
                span: MKCoordinateSpan(latitudeDelta: 100.0, longitudeDelta: 180.0)
            )
        } else {
            // For smaller areas, still use a generous view but centered on clusters
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: MKCoordinateSpan(latitudeDelta: max(latDelta, 100.0), longitudeDelta: max(lonDelta, 180.0))
            )
        }
    }
}

