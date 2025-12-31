//
//  MapService.swift
//  Immich Gallery
//
//  Service for fetching geodata from Immich API
//

import Foundation

class MapService: ObservableObject {
    private let networkService: NetworkService
    
    init(networkService: NetworkService) {
        self.networkService = networkService
    }
    
    /// Fetches all assets with geolocation data (latitude and longitude)
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
}

