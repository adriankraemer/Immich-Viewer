import Foundation
import Combine

class ExploreService: ObservableObject {
    private let networkService: NetworkService
    
    /// Cache for location summaries
    private var cachedSummaries: [LocationSummary]?
    private var summaryCacheTime: Date?
    
    /// Cache for map markers
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
                debugLog("ExploreService: Cache invalidated due to user switch")
            }
            .store(in: &cancellables)
    }
    
    /// Fetch lightweight location summaries using the map markers API (FAST)
    /// This uses /api/map/markers which returns only location metadata, not full assets
    func fetchLocationSummaries() async throws -> [LocationSummary] {
        // Check cache first
        if let cached = cachedSummaries,
           let cacheTime = summaryCacheTime,
           Date().timeIntervalSince(cacheTime) < cacheValidityDuration {
            debugLog("ExploreService: Returning \(cached.count) cached location summaries")
            return cached
        }
        
        // Use the map markers endpoint - much faster than fetching all assets
        let markers = try await fetchMapMarkers()
        
        // Count markers per country and track representatives
        var countryCounts: [String: Int] = [:]
        var countryRepresentatives: [String: String] = [:]
        
        for marker in markers {
            guard let country = marker.country, !country.isEmpty else { continue }
            
            countryCounts[country, default: 0] += 1
            
            // Keep first marker as representative
            if countryRepresentatives[country] == nil {
                countryRepresentatives[country] = marker.id
            }
        }
        
        // Convert to LocationSummary array
        let summaries = countryCounts.map { country, count in
            LocationSummary(
                country: country,
                count: count,
                representativeAssetId: countryRepresentatives[country]
            )
        }
        
        // Cache the results
        cachedSummaries = summaries
        summaryCacheTime = Date()
        
        debugLog("ExploreService: Built \(summaries.count) location summaries from \(markers.count) markers")
        return summaries
    }
    
    /// Fetch map markers from the dedicated endpoint (with caching)
    private func fetchMapMarkers() async throws -> [MapMarker] {
        // Check cache first
        if let cached = cachedMarkers,
           let cacheTime = markersCacheTime,
           Date().timeIntervalSince(cacheTime) < cacheValidityDuration {
            return cached
        }
        
        let data = try await networkService.makeDataRequest(endpoint: "/api/map/markers")
        
        var markers: [MapMarker]
        
        // Try to decode as array first
        if let decoded = try? JSONDecoder().decode([MapMarker].self, from: data) {
            markers = decoded
        } else {
            // Try as MapMarkersResponse object
            let response = try JSONDecoder().decode(MapMarkersResponse.self, from: data)
            markers = response.markers ?? []
        }
        
        // Cache the results
        cachedMarkers = markers
        markersCacheTime = Date()
        
        return markers
    }
    
    /// Fetch all assets with location data (used for stats calculation)
    /// Note: This is a heavier operation than fetchLocationSummaries and should be used sparingly
    func fetchAllLocationAssets() async throws -> [ImmichAsset] {
        var allAssets: [ImmichAsset] = []
        var page = 1
        let pageSize = 1000
        
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
            
            // Filter assets that have country information in EXIF
            let assetsWithCountry = result.assets.items.filter { asset in
                guard let exifInfo = asset.exifInfo,
                      let country = exifInfo.country,
                      !country.isEmpty else {
                    return false
                }
                return true
            }
            
            allAssets.append(contentsOf: assetsWithCountry)
            
            // Check if there are more pages
            if result.assets.nextPage == nil || result.assets.items.isEmpty {
                break
            }
            
            page += 1
        }
        
        return allAssets
    }
    
    /// Get asset IDs for a specific country from cached map markers
    func getAssetIdsForCountry(_ countryName: String) async throws -> [String] {
        let markers = try await fetchMapMarkers()
        
        let normalizedSearchCountry = countryName.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Filter markers that match this country
        let matchingIds = markers.compactMap { marker -> String? in
            guard let country = marker.country, !country.isEmpty else { return nil }
            
            let normalizedMarkerCountry = country.lowercased().trimmingCharacters(in: .whitespaces)
            let canonicalMarkerCountry = ContinentMapper.getCanonicalCountryName(from: normalizedMarkerCountry, original: country)
            
            if canonicalMarkerCountry.lowercased() == normalizedSearchCountry ||
               normalizedMarkerCountry == normalizedSearchCountry ||
               country.lowercased() == normalizedSearchCountry {
                return marker.id
            }
            return nil
        }
        
        return matchingIds
    }
    
    /// Fetch assets by their IDs (paginated)
    func fetchAssetsByIds(_ ids: [String], page: Int, limit: Int) async throws -> SearchResult {
        guard !ids.isEmpty else {
            return SearchResult(assets: [], total: 0, nextPage: nil)
        }
        
        let pageSize = max(limit, 1)
        let startIndex = max((page - 1) * pageSize, 0)
        let endIndex = min(startIndex + pageSize, ids.count)
        
        guard startIndex < ids.count else {
            return SearchResult(assets: [], total: ids.count, nextPage: nil)
        }
        
        let pageIds = Array(ids[startIndex..<endIndex])
        
        // Fetch assets by ID using bulk endpoint or individual requests
        var assets: [ImmichAsset] = []
        
        // Try bulk fetch first
        let searchRequest: [String: Any] = [
            "id": ["in": pageIds],
            "withExif": true,
            "withPeople": true
        ]
        
        do {
            let result: SearchResponse = try await networkService.makeRequest(
                endpoint: "/api/search/metadata",
                method: .POST,
                body: searchRequest,
                responseType: SearchResponse.self
            )
            assets = result.assets.items
        } catch {
            debugLog("ExploreService: Bulk fetch failed, falling back to individual fetches: \(error)")
            // Fallback: fetch individually (slower but more reliable)
            for id in pageIds {
                do {
                    let asset: ImmichAsset = try await networkService.makeRequest(
                        endpoint: "/api/assets/\(id)",
                        method: .GET,
                        responseType: ImmichAsset.self
                    )
                    assets.append(asset)
                } catch {
                    debugLog("ExploreService: Failed to fetch asset \(id): \(error)")
                }
            }
        }
        
        let hasMore = endIndex < ids.count
        let nextPage: String? = hasMore ? String(page + 1) : nil
        
        return SearchResult(
            assets: assets,
            total: ids.count,
            nextPage: nextPage
        )
    }
    
    /// Invalidate the cache (e.g., on user switch)
    func invalidateCache() {
        cachedSummaries = nil
        summaryCacheTime = nil
        cachedMarkers = nil
        markersCacheTime = nil
    }
}