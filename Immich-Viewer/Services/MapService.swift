import Foundation
import MapKit
import Combine

class MapService: ObservableObject {
    private let networkService: NetworkService
    
    /// Cache for map markers to avoid re-fetching
    private var cachedMarkers: [MapMarker]?
    private var markersCacheTime: Date?
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes
    
    /// Cancellables for notification subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    init(networkService: NetworkService) {
        self.networkService = networkService
        
        // Listen for user switch notifications to invalidate cache
        NotificationCenter.default.publisher(for: NSNotification.Name(NotificationNames.refreshAllTabs))
            .sink { [weak self] _ in
                self?.invalidateCache()
                debugLog("MapService: Cache invalidated due to user switch")
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Lightweight Map Markers (Fast Initial Load)
    
    /// Fetches lightweight map markers for fast initial map rendering
    /// Uses the /api/map/markers endpoint if available, falls back to metadata search
    func fetchMapMarkers() async throws -> [MapMarker] {
        // Check cache first
        if let cached = cachedMarkers,
           let cacheTime = markersCacheTime,
           Date().timeIntervalSince(cacheTime) < cacheValidityDuration {
            debugLog("MapService: Returning \(cached.count) cached markers")
            return cached
        }
        
        // Try the dedicated map markers endpoint first (faster)
        do {
            let markers = try await fetchMarkersFromMapEndpoint()
            cachedMarkers = markers
            markersCacheTime = Date()
            debugLog("MapService: Fetched \(markers.count) markers from map endpoint")
            return markers
        } catch {
            debugLog("MapService: Map markers endpoint failed, falling back to metadata search: \(error)")
            // Fall back to metadata search
            let markers = try await fetchMarkersFromMetadataSearch()
            cachedMarkers = markers
            markersCacheTime = Date()
            return markers
        }
    }
    
    /// Fetches markers from the dedicated /api/map/markers endpoint
    private func fetchMarkersFromMapEndpoint() async throws -> [MapMarker] {
        // Try to fetch from the map markers endpoint
        let data = try await networkService.makeDataRequest(endpoint: "/api/map/markers")
        
        // Try to decode as array first (most common response format)
        if let markers = try? JSONDecoder().decode([MapMarker].self, from: data) {
            return markers.filter { marker in
                // Validate coordinates
                marker.lat >= -90 && marker.lat <= 90 &&
                marker.lon >= -180 && marker.lon <= 180
            }
        }
        
        // Try as MapMarkersResponse object
        let response = try JSONDecoder().decode(MapMarkersResponse.self, from: data)
        return (response.markers ?? []).filter { marker in
            marker.lat >= -90 && marker.lat <= 90 &&
            marker.lon >= -180 && marker.lon <= 180
        }
    }
    
    /// Fetches markers by converting from metadata search results
    /// Used as fallback when map markers endpoint is not available
    private func fetchMarkersFromMetadataSearch() async throws -> [MapMarker] {
        var allMarkers: [MapMarker] = []
        var page = 1
        let pageSize = 1000
        
        // Limit to first few pages for initial fast load
        // More data will be loaded on-demand when zooming
        let maxInitialPages = 5
        
        while page <= maxInitialPages {
            let searchRequest: [String: Any] = [
                "page": page,
                "size": pageSize,
                "withExif": true,
                "order": "desc"
            ]
            
            let result: SearchResponse = try await networkService.makeRequest(
                endpoint: "/api/search/metadata",
                method: .POST,
                body: searchRequest,
                responseType: SearchResponse.self
            )
            
            // Convert assets to lightweight markers
            let markers = result.assets.items.compactMap { asset -> MapMarker? in
                guard let exifInfo = asset.exifInfo,
                      let latitude = exifInfo.latitude,
                      let longitude = exifInfo.longitude,
                      latitude >= -90 && latitude <= 90,
                      longitude >= -180 && longitude <= 180 else {
                    return nil
                }
                
                return MapMarker(
                    id: asset.id,
                    lat: latitude,
                    lon: longitude,
                    city: exifInfo.city,
                    state: exifInfo.state,
                    country: exifInfo.country
                )
            }
            
            allMarkers.append(contentsOf: markers)
            
            // Check if there are more pages
            if result.assets.nextPage == nil || result.assets.items.isEmpty {
                break
            }
            
            page += 1
        }
        
        debugLog("MapService: Converted \(allMarkers.count) assets to markers from metadata search")
        return allMarkers
    }
    
    // MARK: - Full Asset Data (On-Demand Detail Loading)
    
    /// Fetches full asset data for specific asset IDs
    /// Used when user zooms in and needs detailed asset information
    func fetchAssetsById(ids: [String]) async throws -> [ImmichAsset] {
        guard !ids.isEmpty else { return [] }
        
        // Batch fetch assets by ID
        // Immich may have a bulk fetch endpoint, otherwise we search
        var assets: [ImmichAsset] = []
        
        // Fetch in batches to avoid overwhelming the server
        let batchSize = 100
        for batchStart in stride(from: 0, to: ids.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, ids.count)
            let batchIds = Array(ids[batchStart..<batchEnd])
            
            let searchRequest: [String: Any] = [
                "id": ["in": batchIds],
                "withExif": true
            ]
            
            do {
                let result: SearchResponse = try await networkService.makeRequest(
                    endpoint: "/api/search/metadata",
                    method: .POST,
                    body: searchRequest,
                    responseType: SearchResponse.self
                )
                assets.append(contentsOf: result.assets.items)
            } catch {
                debugLog("MapService: Failed to fetch batch of assets: \(error)")
                // Continue with other batches
            }
        }
        
        return assets
    }
    
    /// Fetches assets within a specific geographic region
    /// Used for loading detailed data when zoomed into a specific area
    func fetchAssetsInRegion(_ region: MKCoordinateRegion, limit: Int = 500) async throws -> [ImmichAsset] {
        let bounds = calculateBounds(for: region)
        
        let searchRequest: [String: Any] = [
            "page": 1,
            "size": limit,
            "withExif": true,
            "order": "desc"
        ]
        
        let result: SearchResponse = try await networkService.makeRequest(
            endpoint: "/api/search/metadata",
            method: .POST,
            body: searchRequest,
            responseType: SearchResponse.self
        )
        
        // Filter to assets within the region
        let assetsInRegion = result.assets.items.filter { asset in
            guard let exifInfo = asset.exifInfo,
                  let latitude = exifInfo.latitude,
                  let longitude = exifInfo.longitude else {
                return false
            }
            
            return latitude >= bounds.minLat &&
                   latitude <= bounds.maxLat &&
                   longitude >= bounds.minLon &&
                   longitude <= bounds.maxLon
        }
        
        return assetsInRegion
    }
    
    // MARK: - Legacy Full Data Fetch
    
    /// Fetches all assets with geolocation data (latitude and longitude)
    /// This is the original heavy-weight method - use fetchMapMarkers() for faster initial load
    func fetchGeodata() async throws -> [ImmichAsset] {
        var allAssets: [ImmichAsset] = []
        var page = 1
        let pageSize = 1000 // Large page size to minimize requests
        
        while true {
            let searchRequest: [String: Any] = [
                "page": page,
                "size": pageSize,
                "withExif": true,
                "order": "desc"
            ]
            
            let result: SearchResponse = try await networkService.makeRequest(
                endpoint: "/api/search/metadata",
                method: .POST,
                body: searchRequest,
                responseType: SearchResponse.self
            )
            
            // Filter assets that have latitude and longitude in EXIF
            let assetsWithLocation = result.assets.items.filter { asset in
                guard let exifInfo = asset.exifInfo,
                      let latitude = exifInfo.latitude,
                      let longitude = exifInfo.longitude else {
                    return false
                }
                // Validate coordinates are within valid ranges
                return latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180
            }
            
            allAssets.append(contentsOf: assetsWithLocation)
            
            // Check if there are more pages
            if result.assets.nextPage == nil || result.assets.items.isEmpty {
                break
            }
            
            page += 1
        }
        
        return allAssets
    }
    
    // MARK: - Cache Management
    
    /// Invalidates the markers cache
    func invalidateCache() {
        cachedMarkers = nil
        markersCacheTime = nil
    }
    
    // MARK: - Helper Methods
    
    private func calculateBounds(for region: MKCoordinateRegion) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        let center = region.center
        let span = region.span
        return (
            center.latitude - span.latitudeDelta / 2,
            center.latitude + span.latitudeDelta / 2,
            center.longitude - span.longitudeDelta / 2,
            center.longitude + span.longitudeDelta / 2
        )
    }
}

