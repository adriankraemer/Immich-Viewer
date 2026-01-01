//
//  AssetProvider.swift
//  Immich-AppleTV
//
//  Created by Adrian Kraemer on 2025-08-19.
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
        albumService: AlbumService? = nil
    ) -> AssetProvider {
        
        if let albumId = albumId, let albumService = albumService {
            return AlbumAssetProvider(albumService: albumService, albumId: albumId)
        } else {
            return GeneralAssetProvider(
                assetService: assetService,
                personId: personId,
                tagId: tagId,
                city: city,
                isAllPhotos: isAllPhotos,
                isFavorite: isFavorite,
                folderPath: folderPath
            )
        }
    }
}

protocol AssetProvider {
    func fetchAssets(page: Int, limit: Int) async throws -> SearchResult
    func fetchRandomAssets(limit: Int) async throws -> SearchResult
}

class AlbumAssetProvider: AssetProvider {
    private let albumService: AlbumService
    private let albumId: String
    private var cachedAssets: [ImmichAsset]?
    
    private enum SortOrder {
        case newestFirst
        case oldestFirst
    }
    
    private static let isoFormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    init(albumService: AlbumService, albumId: String) {
        self.albumService = albumService
        self.albumId = albumId
    }

    private func loadAlbumAssets() async throws -> [ImmichAsset] {
        if let cachedAssets {
            return cachedAssets
        }

        // Fetch the album with full asset list; Immich includes assets unless withoutAssets is true
        let album = try await albumService.getAlbumInfo(albumId: albumId, withoutAssets: false)
        cachedAssets = album.assets
        return album.assets
    }
    
    func fetchAssets(page: Int, limit: Int) async throws -> SearchResult {
        let assets = try await loadAlbumAssets()
        let sortedAssets = sortAssets(assets)
        guard !assets.isEmpty else {
            return SearchResult(assets: [], total: 0, nextPage: nil)
        }

        let pageSize = max(limit, 1)
        let startIndex = max((page - 1) * pageSize, 0)
        let endIndex = min(startIndex + pageSize, sortedAssets.count)

        let pageAssets: [ImmichAsset]
        if startIndex < endIndex {
            pageAssets = Array(sortedAssets[startIndex..<endIndex])
        } else {
            pageAssets = []
        }

        let nextPage: String? = endIndex < sortedAssets.count ? String(page + 1) : nil

        return SearchResult(
            assets: pageAssets,
            total: sortedAssets.count,
            nextPage: nextPage
        )
    }
    
    func fetchRandomAssets(limit: Int) async throws -> SearchResult {
        let assets = try await loadAlbumAssets()
        guard !assets.isEmpty else {
            return SearchResult(assets: [], total: 0, nextPage: nil)
        }

        let sampleCount = min(limit, assets.count)
        let shuffledAssets = Array(assets.shuffled().prefix(sampleCount))

        return SearchResult(
            assets: shuffledAssets,
            total: assets.count,
            nextPage: nil
        )
    }
    
    private func sortAssets(_ assets: [ImmichAsset]) -> [ImmichAsset] {
        let sortOrder = currentSortOrder()
        return assets.sorted { lhs, rhs in
            let lhsDate = captureDate(for: lhs)
            let rhsDate = captureDate(for: rhs)
            
            if lhsDate == rhsDate {
                return lhs.id < rhs.id
            }
            
            switch sortOrder {
            case .newestFirst:
                return lhsDate > rhsDate
            case .oldestFirst:
                return lhsDate < rhsDate
            }
        }
    }
    
    private func currentSortOrder() -> SortOrder {
        let storedValue = UserDefaults.standard.string(forKey: UserDefaultsKeys.assetSortOrder) ?? "desc"
        return storedValue.lowercased() == "asc" ? .oldestFirst : .newestFirst
    }
    
    private func captureDate(for asset: ImmichAsset) -> Date {
        if let date = parseDate(asset.exifInfo?.dateTimeOriginal) {
            return date
        }
        if let date = parseDate(asset.fileCreatedAt) {
            return date
        }
        if let date = parseDate(asset.fileModifiedAt) {
            return date
        }
        if let date = parseDate(asset.updatedAt) {
            return date
        }
        
        return .distantPast
    }
    
    private func parseDate(_ value: String?) -> Date? {
        guard let value = value else { return nil }
        if let date = AlbumAssetProvider.isoFormatterWithFractional.date(from: value) {
            return date
        }
        return AlbumAssetProvider.isoFormatter.date(from: value)
    }
}

/// Asset provider that fetches assets for a country on-demand with pagination
/// Uses map markers to get asset IDs first (fast), then fetches assets in batches
class OnDemandCountryAssetProvider: AssetProvider {
    private let countryName: String
    private let exploreService: ExploreService
    
    /// Asset IDs for this country (from map markers - fast to get)
    private var assetIds: [String]?
    /// Cached fetched assets keyed by ID
    private var fetchedAssets: [String: ImmichAsset] = [:]
    
    private enum SortOrder {
        case newestFirst
        case oldestFirst
    }
    
    private static let isoFormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    init(countryName: String, exploreService: ExploreService) {
        self.countryName = countryName
        self.exploreService = exploreService
    }
    
    /// Get asset IDs for this country (uses cached map markers - very fast)
    private func getAssetIds() async throws -> [String] {
        if let ids = assetIds {
            return ids
        }
        
        let ids = try await exploreService.getAssetIdsForCountry(countryName)
        assetIds = ids
        print("OnDemandCountryAssetProvider: Found \(ids.count) assets for \(countryName)")
        return ids
    }
    
    func fetchAssets(page: Int, limit: Int) async throws -> SearchResult {
        // First, get all asset IDs for this country (fast - uses map markers cache)
        let ids = try await getAssetIds()
        
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
        
        // Check which assets we already have cached
        var assetsToFetch: [String] = []
        var cachedAssets: [ImmichAsset] = []
        
        for id in pageIds {
            if let asset = fetchedAssets[id] {
                cachedAssets.append(asset)
            } else {
                assetsToFetch.append(id)
            }
        }
        
        // Fetch missing assets
        if !assetsToFetch.isEmpty {
            let result = try await exploreService.fetchAssetsByIds(assetsToFetch, page: 1, limit: assetsToFetch.count)
            for asset in result.assets {
                fetchedAssets[asset.id] = asset
            }
        }
        
        // Build final page assets in order
        var pageAssets: [ImmichAsset] = []
        for id in pageIds {
            if let asset = fetchedAssets[id] {
                pageAssets.append(asset)
            }
        }
        
        // Sort the page
        let sortedAssets = sortAssets(pageAssets)
        
        let hasMore = endIndex < ids.count
        let nextPage: String? = hasMore ? String(page + 1) : nil
        
        return SearchResult(
            assets: sortedAssets,
            total: ids.count,
            nextPage: nextPage
        )
    }
    
    func fetchRandomAssets(limit: Int) async throws -> SearchResult {
        let ids = try await getAssetIds()
        
        guard !ids.isEmpty else {
            return SearchResult(assets: [], total: 0, nextPage: nil)
        }
        
        // Shuffle and take a sample of IDs
        let sampleCount = min(limit, ids.count)
        let sampleIds = Array(ids.shuffled().prefix(sampleCount))
        
        // Fetch these specific assets
        let result = try await exploreService.fetchAssetsByIds(sampleIds, page: 1, limit: sampleCount)
        
        // Cache them
        for asset in result.assets {
            fetchedAssets[asset.id] = asset
        }
        
        return SearchResult(
            assets: result.assets,
            total: ids.count,
            nextPage: nil
        )
    }
    
    private func sortAssets(_ assets: [ImmichAsset]) -> [ImmichAsset] {
        let sortOrder = currentSortOrder()
        return assets.sorted { lhs, rhs in
            let lhsDate = captureDate(for: lhs)
            let rhsDate = captureDate(for: rhs)
            
            if lhsDate == rhsDate {
                return lhs.id < rhs.id
            }
            
            switch sortOrder {
            case .newestFirst:
                return lhsDate > rhsDate
            case .oldestFirst:
                return lhsDate < rhsDate
            }
        }
    }
    
    private func currentSortOrder() -> SortOrder {
        let storedValue = UserDefaults.standard.string(forKey: UserDefaultsKeys.assetSortOrder) ?? "desc"
        return storedValue.lowercased() == "asc" ? .oldestFirst : .newestFirst
    }
    
    private func captureDate(for asset: ImmichAsset) -> Date {
        if let date = parseDate(asset.exifInfo?.dateTimeOriginal) {
            return date
        }
        if let date = parseDate(asset.fileCreatedAt) {
            return date
        }
        if let date = parseDate(asset.fileModifiedAt) {
            return date
        }
        if let date = parseDate(asset.updatedAt) {
            return date
        }
        
        return .distantPast
    }
    
    private func parseDate(_ value: String?) -> Date? {
        guard let value = value else { return nil }
        if let date = OnDemandCountryAssetProvider.isoFormatterWithFractional.date(from: value) {
            return date
        }
        return OnDemandCountryAssetProvider.isoFormatter.date(from: value)
    }
}

class GeneralAssetProvider: AssetProvider {
    private let assetService: AssetService
    private let personId: String?
    private let tagId: String?
    private let city: String?
    private let isAllPhotos: Bool
    private let isFavorite: Bool
    private let folderPath: String?
    
    init(assetService: AssetService, personId: String? = nil, tagId: String? = nil, city: String? = nil, isAllPhotos: Bool = false, isFavorite: Bool = false, folderPath: String? = nil) {
        self.assetService = assetService
        self.personId = personId
        self.tagId = tagId
        self.city = city
        self.isAllPhotos = isAllPhotos
        self.isFavorite = isFavorite
        self.folderPath = folderPath
    }
    
    func fetchAssets(page: Int, limit: Int) async throws -> SearchResult {
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
    
    func fetchRandomAssets(limit: Int) async throws -> SearchResult {
        return try await assetService.fetchRandomAssets(
            albumIds: nil,
            personIds: personId != nil ? [personId!] : nil,
            tagIds: tagId != nil ? [tagId!] : nil,
            folderPath: folderPath,
            limit: limit
        )
    }
}
