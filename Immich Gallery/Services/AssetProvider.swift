//
//  AssetProvider.swift
//  Immich Gallery
//
//  Created by mensadi-labs on 2025-08-19.
//

import Foundation

struct AssetProviderFactory {
    static func createProvider(
        albumId: String? = nil,
        personId: String? = nil,
        tagId: String? = nil,
        city: String? = nil,
        isAllPhotos: Bool = false,
        isFavorite: Bool = false,
        folderPath: String? = nil,
        assetService: AssetService,
        albumService: AlbumService? = nil,
        config: SlideshowConfig? = nil
    ) -> AssetProvider {
        
        if let albumId = albumId, let albumService = albumService {
            return AlbumAssetProvider(albumService: albumService, assetService: assetService, albumId: albumId)
        } else {
            return GeneralAssetProvider(
                assetService: assetService,
                personId: personId,
                tagId: tagId,
                city: city,
                isAllPhotos: isAllPhotos,
                isFavorite: isFavorite,
                folderPath: folderPath,
                config: config
            )
        }
    }
}

protocol AssetProvider {
    func fetchAssets(page: Int, limit: Int) async throws -> SearchResult
    func fetchRandomAssets(limit: Int) async throws -> SearchResult
}

class AlbumAssetProvider: AssetProvider {
    private let assetService: AssetService
    private let albumId: String

    init(albumService _: AlbumService, assetService: AssetService, albumId: String) {
        self.assetService = assetService
        self.albumId = albumId
    }
    
    func fetchAssets(page: Int, limit: Int) async throws -> SearchResult {
        return try await assetService.fetchAssets(
            page: page,
            limit: limit,
            albumId: albumId,
            personId: nil,
            tagId: nil,
            city: nil,
            isAllPhotos: false,
            isFavorite: false
        )
    }
    
    func fetchRandomAssets(limit: Int) async throws -> SearchResult {
        return try await assetService.fetchRandomAssets(
            albumIds: [albumId],
            personIds: nil,
            tagIds: nil,
            limit: limit
        )
    }
}

class GeneralAssetProvider: AssetProvider {
    private let assetService: AssetService
    private let personId: String?
    private let tagId: String?
    private let city: String?
    private let isAllPhotos: Bool
    private let isFavorite: Bool
    private let config: SlideshowConfig?
    private let folderPath: String?
    
    init(assetService: AssetService, personId: String? = nil, tagId: String? = nil, city: String? = nil, isAllPhotos: Bool = false, isFavorite: Bool = false, folderPath: String? = nil, config: SlideshowConfig? = nil) {
        self.assetService = assetService
        self.personId = personId
        self.tagId = tagId
        self.city = city
        self.isAllPhotos = isAllPhotos
        self.isFavorite = isFavorite
        self.config = config
        self.folderPath = folderPath
    }
    
    func fetchAssets(page: Int, limit: Int) async throws -> SearchResult {
        // If config is provided, use it; otherwise fall back to individual parameters
        if let config = config {
            return try await assetService.fetchAssets(config: config, page: page, limit: limit, isAllPhotos: isAllPhotos)
        } else {
            return try await assetService.fetchAssets(
                page: page,
                limit: limit,
                albumId: nil,
                personId: personId,
                tagId: tagId,
                city: city,
                isAllPhotos: isAllPhotos,
                isFavorite: isFavorite,
                folderPath: folderPath
            )
        }
    }
    
    func fetchRandomAssets(limit: Int) async throws -> SearchResult {
        // If config is provided, use it; otherwise fall back to individual parameters
        if let config = config {
            return try await assetService.fetchRandomAssets(config: config, limit: limit)
        } else {
            return try await assetService.fetchRandomAssets(
                albumIds: nil,
                personIds: personId != nil ? [personId!] : nil,
                tagIds: tagId != nil ? [tagId!] : nil,
                folderPath: folderPath,
                limit: limit
            )
        }
    }
}
