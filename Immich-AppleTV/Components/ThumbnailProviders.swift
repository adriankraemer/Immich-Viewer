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
        
        if let thumbnail = await loadThumbnail(for: album) {
            return [thumbnail]
        }
        
        return []
    }
    
    private func loadThumbnail(for album: ImmichAlbum) async -> UIImage? {
        guard let thumbnailId = album.albumThumbnailAssetId, !thumbnailId.isEmpty else {
            return nil
        }
        
        do {
            return try await thumbnailCache.getThumbnail(for: thumbnailId, size: "thumbnail") {
                try await self.assetService.loadImage(assetId: thumbnailId, size: "thumbnail")
            }
        } catch {
            debugLog("Failed to load thumbnail for album \(album.id): \(error)")
            return nil
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
            let searchResult = try await assetService.fetchAssets(page: 1, limit: 1, personId: person.id)
            guard let asset = searchResult.assets.first(where: { $0.type == .image }) else { return [] }
            
            let thumbnail = try await thumbnailCache.getThumbnail(for: asset.id, size: "thumbnail") {
                try await self.assetService.loadImage(assetId: asset.id, size: "thumbnail")
            }
            if let thumbnail = thumbnail {
                return [thumbnail]
            }
        } catch {
            debugLog("Failed to fetch assets for person \(person.id): \(error)")
        }
        return []
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
            let searchResult = try await assetService.fetchAssets(page: 1, limit: 1, tagId: tag.id)
            guard let asset = searchResult.assets.first(where: { $0.type == .image }) else { return [] }
            
            let thumbnail = try await thumbnailCache.getThumbnail(for: asset.id, size: "thumbnail") {
                try await self.assetService.loadImage(assetId: asset.id, size: "thumbnail")
            }
            if let thumbnail = thumbnail {
                return [thumbnail]
            }
        } catch {
            debugLog("Failed to fetch assets for tag \(tag.id): \(error)")
        }
        return []
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
            let searchResult = try await assetService.fetchAssets(page: 1, limit: 1, folderPath: folder.path)
            guard let asset = searchResult.assets.first(where: { $0.type == .image }) else { return [] }
            
            let thumbnail = try await thumbnailCache.getThumbnail(for: asset.id, size: "thumbnail") {
                try await self.assetService.loadImage(assetId: asset.id, size: "thumbnail")
            }
            if let thumbnail = thumbnail {
                return [thumbnail]
            }
        } catch {
            debugLog("Failed to fetch assets for folder \(folder.path): \(error)")
        }
        return []
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
        
        // Use continent representative asset, or first country's representative asset
        let assetId: String? = continent.representativeAssetId ?? continent.countries.first?.representativeAssetId
        
        guard let assetId = assetId else { return [] }
        
        do {
            let thumbnail = try await thumbnailCache.getThumbnail(for: assetId, size: "thumbnail") {
                try await self.assetService.loadImage(assetId: assetId, size: "thumbnail")
            }
            if let thumbnail = thumbnail {
                return [thumbnail]
            }
        } catch {
            debugLog("Failed to load thumbnail for continent asset \(assetId): \(error)")
        }
        
        return []
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
