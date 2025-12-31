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
    
    // MARK: - Dependencies
    private let mapService: MapService
    private let assetService: AssetService
    
    // MARK: - Initialization
    init(mapService: MapService, assetService: AssetService) {
        self.mapService = mapService
        self.assetService = assetService
    }
    
    // MARK: - Public Methods
    func loadMapData() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let assets = try await mapService.fetchGeodata()
            
            // Cluster the photos
            let photoClusters = MapClusterer.clusterPhotos(assets)
            clusters = photoClusters
            
            // Update map region to show all clusters
            if !clusters.isEmpty {
                updateRegionToFitClusters()
            }
            
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
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
    }
    
    func zoomOut() {
        let currentSpan = region.span
        let newLatDelta = min(currentSpan.latitudeDelta * 1.3, 90.0)
        let newLonDelta = min(currentSpan.longitudeDelta * 1.3, 180.0)
        
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

