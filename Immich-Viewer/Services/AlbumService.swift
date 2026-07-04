import Foundation
import UIKit

/// Service responsible for album operations
class AlbumService: ObservableObject {
    private let networkService: NetworkService

    init(networkService: NetworkService) {
        self.networkService = networkService
    }

    func fetchAlbums() async throws -> [ImmichAlbum] {
        debugLog("AlbumService: Fetching albums from /api/albums")
        // v2 uses `shared`, v3 renamed it to `isShared`; each version ignores the unknown parameter
        let albums = try await networkService.makeRequest(
            endpoint: "/api/albums?shared=false&isShared=false",
            responseType: [ImmichAlbum].self
        )

        let sharedAlbums = try await networkService.makeRequest(
            endpoint: "/api/albums?shared=true&isShared=true",
            responseType: [ImmichAlbum].self
        )
        debugLog("AlbumService: Received \(albums.count) albums")

        // Deduplicate by id in case both requests return overlapping results
        var seenIds = Set<String>()
        return (albums + sharedAlbums).filter { seenIds.insert($0.id).inserted }
    }

    func getAlbumInfo(albumId: String, withoutAssets: Bool = false) async throws -> ImmichAlbum {
        var endpoint = "/api/albums/\(albumId)"
        if withoutAssets {
            endpoint += "?withoutAssets=true"
        }
        return try await networkService.makeRequest(
            endpoint: endpoint,
            responseType: ImmichAlbum.self
        )
    }

    func loadAlbumThumbnail(albumId: String, thumbnailAssetId: String, size: String = "thumbnail") async throws -> UIImage? {
        let endpoint = "/api/assets/\(thumbnailAssetId)/thumbnail?format=webp&size=\(size)"
        let data = try await networkService.makeDataRequest(endpoint: endpoint)
        return UIImage(data: data)
    }
} 
