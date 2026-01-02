//
//  AssetService.swift
//  Immich-AppleTV
//

import Foundation
import UIKit

/// Service responsible for asset fetching, searching, and image loading
class AssetService: ObservableObject {
    private let networkService: NetworkService

    init(networkService: NetworkService) {
        self.networkService = networkService
    }
    
    // MARK: - Image Orientation Correction
    
    /// Normalizes image orientation by redrawing the image with correct orientation applied.
    /// This fixes images that appear rotated or flipped due to EXIF orientation metadata
    /// not being properly applied during display.
    private func normalizeImageOrientation(_ image: UIImage) -> UIImage {
        // If orientation is already up, no processing needed
        guard image.imageOrientation != .up else {
            return image
        }
        
        // Redraw the image with the correct orientation applied
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? image
    }

    /// Fetches assets with optional filtering by album, person, tag, city, favorites, or folder
    /// Uses different sort orders for All Photos tab vs other views
    func fetchAssets(page: Int = 1, limit: Int? = nil, albumId: String? = nil, personId: String? = nil, tagId: String? = nil, city: String? = nil, isAllPhotos: Bool = false, isFavorite: Bool = false, folderPath: String? = nil) async throws -> SearchResult {
        // Use separate sort order preference for All Photos tab vs other views
        let sortOrder = isAllPhotos 
            ? UserDefaults.standard.allPhotosSortOrder
            : (UserDefaults.standard.string(forKey: "assetSortOrder") ?? "desc")
        var searchRequest: [String: Any] = [
            "page": page,
            "withPeople": true,
            "order": sortOrder,
            "withExif": true,
        ]

        if let limit = limit {
            searchRequest["size"] = limit
        }

        if let albumId = albumId {
            searchRequest["albumIds"] = [albumId]
        }
        if let personId = personId {
            searchRequest["personIds"] = [personId]
        }
        if let tagId = tagId {
            searchRequest["tagIds"] = [tagId]
        }
        if isFavorite {
            searchRequest["isFavorite"] = true
        }
        if let city = city {
            searchRequest["city"] = city
        }
        if let folderPath = folderPath, !folderPath.isEmpty {
            searchRequest["originalPath"] = folderPath
            searchRequest["path"] = folderPath
            searchRequest["originalPathPrefix"] = folderPath
        }
        let result: SearchResponse = try await networkService.makeRequest(
            endpoint: "/api/search/metadata",
            method: .POST,
            body: searchRequest,
            responseType: SearchResponse.self
        )
        return SearchResult(
            assets: result.assets.items,
            total: result.assets.total,
            nextPage: result.assets.nextPage
        )
    }

    func loadImage(assetId: String, size: String = "thumbnail") async throws -> UIImage? {
        let endpoint = "/api/assets/\(assetId)/thumbnail?format=webp&size=\(size)"
        let data = try await networkService.makeDataRequest(endpoint: endpoint)
        if let image = UIImage(data: data) {
            // Normalize orientation for thumbnails as well
            return normalizeImageOrientation(image)
        }
        return nil
    }

    /// Loads the full-resolution image for an asset
    /// For RAW formats, uses server-converted preview instead of original (UIImage can't decode RAW)
    /// Automatically corrects image orientation based on EXIF metadata
    func loadFullImage(asset: ImmichAsset) async throws -> UIImage? {
        // Check if it's a RAW format - UIImage can't decode RAW files directly
        if let mimeType = asset.originalMimeType, isRawFormat(mimeType) {
            debugLog("AssetService: Detected RAW format (\(mimeType)), using server-converted version")
            if let convertedImage = try await loadConvertedImage(asset: asset) {
                // Server-converted images should already have correct orientation
                return normalizeImageOrientation(convertedImage)
            }
        }
        
        // Standard processing for non-RAW formats (JPEG, PNG, etc.)
        let originalEndpoint = "/api/assets/\(asset.id)/original"
        let originalData = try await networkService.makeDataRequest(endpoint: originalEndpoint)
        
        if let image = UIImage(data: originalData) {
            debugLog("AssetService: Successfully loaded image for asset \(asset.id), orientation: \(image.imageOrientation.rawValue)")
            // Normalize orientation to fix rotated/flipped images
            let normalizedImage = normalizeImageOrientation(image)
            return normalizedImage
        }
        
        debugLog("AssetService: Failed to load image for asset \(asset.id)")
        return nil
    }
    
    /// Checks if the MIME type represents a RAW camera format
    /// RAW formats need server-side conversion since UIImage can't decode them
    private func isRawFormat(_ mimeType: String) -> Bool {
        let rawMimeTypes = [
            // Standard MIME types
            "image/x-adobe-dng",
            "image/x-canon-cr2",
            "image/x-canon-crw", 
            "image/x-nikon-nef",
            "image/x-sony-arw",
            "image/x-panasonic-raw",
            "image/x-olympus-orf",
            "image/x-fuji-raf",
            
            // Simplified types (common variations)
            "image/nef",
            "image/dng",
            "image/cr2",
            "image/arw",
            "image/orf",
            "image/raf",
            
            // Alternative formats
            "image/x-panasonic-rw2",
            "image/x-kodak-dcr",
            "image/x-sigma-x3f"
        ]
        return rawMimeTypes.contains(mimeType.lowercased())
    }
    
    /// Loads a server-converted version of a RAW image
    /// Uses preview size for best quality while maintaining reasonable file size
    private func loadConvertedImage(asset: ImmichAsset) async throws -> UIImage? {
        // Use preview size for best quality RAW conversion
        let endpoint = "/api/assets/\(asset.id)/thumbnail?format=webp&size=preview"
        
        do {
            let data = try await networkService.makeDataRequest(endpoint: endpoint)
            if let image = UIImage(data: data) {
                debugLog("AssetService: Loaded converted RAW image: \(image.size), orientation: \(image.imageOrientation.rawValue)")
                return image
            }
        } catch {
            debugLog("AssetService: Failed to load converted RAW image: \(error)")
        }
        
        return nil
    }

    /// Returns the playback URL for a video asset
    /// The URL includes authentication and can be used directly with AVPlayer
    func loadVideoURL(asset: ImmichAsset) async throws -> URL {
        guard asset.type == .video else { throw ImmichError.clientError(400) }
        let endpoint = "/api/assets/\(asset.id)/video/playback"
        guard let url = URL(string: "\(networkService.baseURL)\(endpoint)") else {
            throw ImmichError.invalidURL
        }
        // Note: URL includes authentication via networkService baseURL
        return url
    }
    
    /// Fetches a random selection of assets, useful for slideshows and discovery
    /// Supports filtering by albums, people, tags, or folder path
    func fetchRandomAssets(albumIds: [String]? = nil, personIds: [String]? = nil, tagIds: [String]? = nil, folderPath: String? = nil, limit: Int = 50) async throws -> SearchResult {
        var searchRequest: [String: Any] = [
            "size": limit,
            "withPeople": true,
            "withExif": true,
        ]
        
        if let albumIds = albumIds {
            searchRequest["albumIds"] = albumIds
        }
        if let personIds = personIds {
            searchRequest["personIds"] = personIds
        }
        if let tagIds = tagIds {
            searchRequest["tagIds"] = tagIds
        }
        if let folderPath = folderPath, !folderPath.isEmpty {
            searchRequest["originalPath"] = folderPath
            searchRequest["path"] = folderPath
            searchRequest["originalPathPrefix"] = folderPath
        }
        
        let assets: [ImmichAsset] = try await networkService.makeRequest(
            endpoint: "/api/search/random",
            method: .POST,
            body: searchRequest,
            responseType: [ImmichAsset].self
        )
        
        return SearchResult(
            assets: assets,
            total: assets.count,
            nextPage: nil // Random endpoint doesn't have pagination
        )
    }
} 
