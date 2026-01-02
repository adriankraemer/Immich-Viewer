import SwiftUI

// MARK: - Album Thumbnail Provider
@MainActor
class AlbumThumbnailProvider: ThumbnailProvider {
    private let albumService: AlbumService
    private let assetService: AssetService
    private var thumbnailCache: ThumbnailCache { ThumbnailCache.shared }
    
    init(albumService: AlbumService, assetService: AssetService) {
        self.albumService = albumService
        self.assetService = assetService
    }
    
    func loadThumbnails(for item: any GridDisplayable) async -> [UIImage] {
        guard let album = item as? ImmichAlbum else { return [] }
        
        if shouldUseStaticThumbnail(),
           let staticThumbnail = await loadStaticThumbnail(for: album) {
            return [staticThumbnail]
        }
        
        return await loadAnimatedThumbnails(for: album)
    }
    
    private func shouldUseStaticThumbnail() -> Bool {
        return !UserDefaults.standard.enableThumbnailAnimation
    }
    
    private func loadStaticThumbnail(for album: ImmichAlbum) async -> UIImage? {
        guard let thumbnailId = album.albumThumbnailAssetId, !thumbnailId.isEmpty else {
            return nil
        }
        
        do {
            return try await thumbnailCache.getThumbnail(for: thumbnailId, size: "thumbnail") {
                try await self.assetService.loadImage(assetId: thumbnailId, size: "thumbnail")
            }
        } catch {
            debugLog("Failed to load static thumbnail for album \(album.id): \(error)")
            return nil
        }
    }
    
    private func loadAnimatedThumbnails(for album: ImmichAlbum) async -> [UIImage] {
        do {
            let albumProvider = AlbumAssetProvider(albumService: albumService, albumId: album.id)
            let searchResult = try await albumProvider.fetchAssets(page: 1, limit: 10)
            let imageAssets = searchResult.assets.filter { $0.type == .image }
            
            var loadedThumbnails: [UIImage] = []
            
            for asset in imageAssets.prefix(10) {
                do {
                    let thumbnail = try await thumbnailCache.getThumbnail(for: asset.id, size: "thumbnail") {
                        try await self.assetService.loadImage(assetId: asset.id, size: "thumbnail")
                    }
                    if let thumbnail = thumbnail {
                        loadedThumbnails.append(thumbnail)
                    }
                } catch {
                    debugLog("Failed to load thumbnail for asset \(asset.id): \(error)")
                }
            }
            
            return loadedThumbnails
        } catch {
            debugLog("Failed to fetch assets for album \(album.id): \(error)")
            return []
        }
    }
}

// MARK: - People Thumbnail Provider
@MainActor
class PeopleThumbnailProvider: ThumbnailProvider {
    private let assetService: AssetService
    private var thumbnailCache: ThumbnailCache { ThumbnailCache.shared }
    
    init(assetService: AssetService) {
        self.assetService = assetService
    }
    
    func loadThumbnails(for item: any GridDisplayable) async -> [UIImage] {
        guard let person = item as? Person else { return [] }
        
        do {
            let searchResult = try await assetService.fetchAssets(page: 1, limit: 10, personId: person.id)
            let imageAssets = searchResult.assets.filter { $0.type == .image }
            
            var loadedThumbnails: [UIImage] = []
            
            for asset in imageAssets.prefix(10) {
                do {
                    let thumbnail = try await thumbnailCache.getThumbnail(for: asset.id, size: "thumbnail") {
                        try await self.assetService.loadImage(assetId: asset.id, size: "thumbnail")
                    }
                    if let thumbnail = thumbnail {
                        loadedThumbnails.append(thumbnail)
                    }
                } catch {
                    debugLog("Failed to load thumbnail for asset \(asset.id): \(error)")
                }
            }
            
            return loadedThumbnails
        } catch {
            debugLog("Failed to fetch assets for person \(person.id): \(error)")
            return []
        }
    }
}

// MARK: - Tag Thumbnail Provider
@MainActor
class TagThumbnailProvider: ThumbnailProvider {
    private let assetService: AssetService
    private var thumbnailCache: ThumbnailCache { ThumbnailCache.shared }
    
    init(assetService: AssetService) {
        self.assetService = assetService
    }
    
    func loadThumbnails(for item: any GridDisplayable) async -> [UIImage] {
        guard let tag = item as? Tag else { return [] }
        
        do {
            let searchResult = try await assetService.fetchAssets(page: 1, limit: 10, tagId: tag.id)
            let imageAssets = searchResult.assets.filter { $0.type == .image }
            
            var loadedThumbnails: [UIImage] = []
            
            for asset in imageAssets.prefix(10) {
                do {
                    let thumbnail = try await thumbnailCache.getThumbnail(for: asset.id, size: "thumbnail") {
                        try await self.assetService.loadImage(assetId: asset.id, size: "thumbnail")
                    }
                    if let thumbnail = thumbnail {
                        loadedThumbnails.append(thumbnail)
                    }
                } catch {
                    debugLog("Failed to load thumbnail for asset \(asset.id): \(error)")
                }
            }
            
            return loadedThumbnails
        } catch {
            debugLog("Failed to fetch assets for tag \(tag.id): \(error)")
            return []
        }
    }
}

// MARK: - Folder Thumbnail Provider
@MainActor
class FolderThumbnailProvider: ThumbnailProvider {
    private let assetService: AssetService
    private var thumbnailCache: ThumbnailCache { ThumbnailCache.shared }
    
    init(assetService: AssetService) {
        self.assetService = assetService
    }
    
    func loadThumbnails(for item: any GridDisplayable) async -> [UIImage] {
        guard let folder = item as? ImmichFolder else { return [] }
        
        do {
            let searchResult = try await assetService.fetchAssets(page: 1, limit: 10, folderPath: folder.path)
            let imageAssets = searchResult.assets.filter { $0.type == .image }
            
            var loadedThumbnails: [UIImage] = []
            
            for asset in imageAssets.prefix(10) {
                do {
                    let thumbnail = try await thumbnailCache.getThumbnail(for: asset.id, size: "thumbnail") {
                        try await self.assetService.loadImage(assetId: asset.id, size: "thumbnail")
                    }
                    if let thumbnail = thumbnail {
                        loadedThumbnails.append(thumbnail)
                    }
                } catch {
                    debugLog("Failed to load thumbnail for asset \(asset.id): \(error)")
                }
            }
            
            return loadedThumbnails
        } catch {
            debugLog("Failed to fetch assets for folder \(folder.path): \(error)")
            return []
        }
    }
}

// MARK: - Continent Thumbnail Provider
@MainActor
class ContinentThumbnailProvider: ThumbnailProvider {
    private let assetService: AssetService
    private var thumbnailCache: ThumbnailCache { ThumbnailCache.shared }
    
    init(assetService: AssetService) {
        self.assetService = assetService
    }
    
    func loadThumbnails(for item: any GridDisplayable) async -> [UIImage] {
        guard let continent = item as? Continent else { return [] }
        
        // Collect representative asset IDs from all countries in the continent
        var assetIds: [String] = []
        
        for country in continent.countries {
            if let assetId = country.representativeAssetId {
                assetIds.append(assetId)
            }
        }
        
        // If we have a continent representative asset, use it first
        if let continentAssetId = continent.representativeAssetId {
            assetIds.insert(continentAssetId, at: 0)
        }
        
        // Remove duplicates while preserving order
        var seen = Set<String>()
        assetIds = assetIds.filter { seen.insert($0).inserted }
        
        // Load thumbnails from collected asset IDs
        var loadedThumbnails: [UIImage] = []
        
        for assetId in assetIds.prefix(10) {
            do {
                let thumbnail = try await thumbnailCache.getThumbnail(for: assetId, size: "thumbnail") {
                    try await self.assetService.loadImage(assetId: assetId, size: "thumbnail")
                }
                if let thumbnail = thumbnail {
                    loadedThumbnails.append(thumbnail)
                }
            } catch {
                debugLog("Failed to load thumbnail for continent asset \(assetId): \(error)")
            }
        }
        
        return loadedThumbnails
    }
}

// MARK: - Country Thumbnail Provider
@MainActor
class CountryThumbnailProvider: ThumbnailProvider {
    private let assetService: AssetService
    private var thumbnailCache: ThumbnailCache { ThumbnailCache.shared }
    
    init(assetService: AssetService) {
        self.assetService = assetService
    }
    
    func loadThumbnails(for item: any GridDisplayable) async -> [UIImage] {
        guard let country = item as? Country else { return [] }
        
        // For countries, we only have the representative asset ID
        // Load just that single thumbnail
        guard let assetId = country.representativeAssetId else { return [] }
        
        do {
            let thumbnail = try await thumbnailCache.getThumbnail(for: assetId, size: "thumbnail") {
                try await self.assetService.loadImage(assetId: assetId, size: "thumbnail")
            }
            if let thumbnail = thumbnail {
                return [thumbnail]
            }
        } catch {
            debugLog("Failed to load thumbnail for country asset \(assetId): \(error)")
        }
        
        return []
    }
}
