//
//  ExploreService.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-09-05.
//

import Foundation

class ExploreService: ObservableObject {
    private let networkService: NetworkService
    
    init(networkService: NetworkService) {
        self.networkService = networkService
    }
    
    func fetchExploreData() async throws -> [ImmichAsset] {
        // Fetch all assets with EXIF metadata, then filter for those with country information
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
}