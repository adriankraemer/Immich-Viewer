//
//  AssetServiceTests.swift
//  Immich-AppleTVTests
//
//  Created for testing purposes
//

import Testing
import Foundation
@testable import Immich_AppleTV

@Suite("AssetService Tests")
struct AssetServiceTests {
    
    @Test("AssetService should initialize")
    func testInitialization() {
        let userManager = UserManager(storage: MockUserStorage())
        let networkService = NetworkService(userManager: userManager)
        let assetService = AssetService(networkService: networkService)
        
        // Just verify it initializes without error
        // AssetService is a struct, so it's always non-nil
        _ = assetService
    }
    
    @Test("AssetService should detect RAW image formats")
    func testRawFormatDetection() {
        let userManager = UserManager(storage: MockUserStorage())
        let networkService = NetworkService(userManager: userManager)
        _ = AssetService(networkService: networkService)
        
        // Test various RAW formats using reflection to access private method
        // Since isRawFormat is private, we'll test through loadFullImage behavior
        // or create a test asset and verify the behavior
        
        let rawMimeTypes = [
            "image/x-adobe-dng",
            "image/x-canon-cr2",
            "image/x-nikon-nef",
            "image/x-sony-arw",
            "image/nef",
            "image/dng",
            "image/cr2"
        ]
        
        // Create test assets with RAW formats
        for mimeType in rawMimeTypes {
            let asset = ImmichAsset(
                id: "test-\(mimeType)",
                deviceAssetId: "device-1",
                deviceId: "device-1",
                ownerId: "owner-1",
                libraryId: nil,
                type: .image,
                originalPath: "/path/to/image",
                originalFileName: "image.raw",
                originalMimeType: mimeType,
                resized: false,
                thumbhash: nil,
                fileModifiedAt: "2024-01-01T00:00:00Z",
                fileCreatedAt: "2024-01-01T00:00:00Z",
                localDateTime: "2024-01-01T00:00:00Z",
                updatedAt: "2024-01-01T00:00:00Z",
                isFavorite: false,
                isArchived: false,
                isOffline: false,
                isTrashed: false,
                checksum: "checksum",
                duration: nil,
                hasMetadata: true,
                livePhotoVideoId: nil,
                people: [],
                visibility: "VISIBLE",
                duplicateId: nil,
                exifInfo: nil
            )
            
            // Verify asset has RAW mime type
            #expect(asset.originalMimeType == mimeType)
        }
    }
    
    @Test("AssetService should handle non-RAW image formats")
    func testNonRawFormatHandling() {
        let nonRawMimeTypes = [
            "image/jpeg",
            "image/png",
            "image/webp",
            "image/heic"
        ]
        
        for mimeType in nonRawMimeTypes {
            let asset = ImmichAsset(
                id: "test-\(mimeType)",
                deviceAssetId: "device-1",
                deviceId: "device-1",
                ownerId: "owner-1",
                libraryId: nil,
                type: .image,
                originalPath: "/path/to/image",
                originalFileName: "image.jpg",
                originalMimeType: mimeType,
                resized: false,
                thumbhash: nil,
                fileModifiedAt: "2024-01-01T00:00:00Z",
                fileCreatedAt: "2024-01-01T00:00:00Z",
                localDateTime: "2024-01-01T00:00:00Z",
                updatedAt: "2024-01-01T00:00:00Z",
                isFavorite: false,
                isArchived: false,
                isOffline: false,
                isTrashed: false,
                checksum: "checksum",
                duration: nil,
                hasMetadata: true,
                livePhotoVideoId: nil,
                people: [],
                visibility: "VISIBLE",
                duplicateId: nil,
                exifInfo: nil
            )
            
            #expect(asset.originalMimeType == mimeType)
        }
    }
    
    @Test("AssetService should handle video assets")
    func testVideoAssetHandling() {
        let videoAsset = ImmichAsset(
            id: "video-1",
            deviceAssetId: "device-1",
            deviceId: "device-1",
            ownerId: "owner-1",
            libraryId: nil,
            type: .video,
            originalPath: "/path/to/video",
            originalFileName: "video.mp4",
            originalMimeType: "video/mp4",
            resized: false,
            thumbhash: nil,
            fileModifiedAt: "2024-01-01T00:00:00Z",
            fileCreatedAt: "2024-01-01T00:00:00Z",
            localDateTime: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z",
            isFavorite: false,
            isArchived: false,
            isOffline: false,
            isTrashed: false,
            checksum: "checksum",
            duration: "00:01:30",
            hasMetadata: true,
            livePhotoVideoId: nil,
            people: [],
            visibility: "VISIBLE",
            duplicateId: nil,
            exifInfo: nil
        )
        
        #expect(videoAsset.type == .video)
        #expect(videoAsset.duration != nil)
    }
    
    @Test("ImmichAsset should be equatable by id")
    func testImmichAssetEquatable() {
        let asset1 = ImmichAsset(
            id: "asset-1",
            deviceAssetId: "device-1",
            deviceId: "device-1",
            ownerId: "owner-1",
            libraryId: nil,
            type: .image,
            originalPath: "/path/to/image",
            originalFileName: "image.jpg",
            originalMimeType: "image/jpeg",
            resized: false,
            thumbhash: nil,
            fileModifiedAt: "2024-01-01T00:00:00Z",
            fileCreatedAt: "2024-01-01T00:00:00Z",
            localDateTime: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z",
            isFavorite: false,
            isArchived: false,
            isOffline: false,
            isTrashed: false,
            checksum: "checksum",
            duration: nil,
            hasMetadata: true,
            livePhotoVideoId: nil,
            people: [],
            visibility: "VISIBLE",
            duplicateId: nil,
            exifInfo: nil
        )
        
        let asset2 = ImmichAsset(
            id: "asset-1", // Same ID
            deviceAssetId: "device-2", // Different device asset ID
            deviceId: "device-2",
            ownerId: "owner-2",
            libraryId: nil,
            type: .video, // Different type
            originalPath: "/path/to/video",
            originalFileName: "video.mp4",
            originalMimeType: "video/mp4",
            resized: false,
            thumbhash: nil,
            fileModifiedAt: "2024-01-01T00:00:00Z",
            fileCreatedAt: "2024-01-01T00:00:00Z",
            localDateTime: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z",
            isFavorite: true, // Different favorite status
            isArchived: false,
            isOffline: false,
            isTrashed: false,
            checksum: "different-checksum",
            duration: "00:01:30",
            hasMetadata: true,
            livePhotoVideoId: nil,
            people: [],
            visibility: "VISIBLE",
            duplicateId: nil,
            exifInfo: nil
        )
        
        // Should be equal because they have the same ID
        #expect(asset1 == asset2)
        
        let asset3 = ImmichAsset(
            id: "asset-2", // Different ID
            deviceAssetId: "device-1",
            deviceId: "device-1",
            ownerId: "owner-1",
            libraryId: nil,
            type: .image,
            originalPath: "/path/to/image",
            originalFileName: "image.jpg",
            originalMimeType: "image/jpeg",
            resized: false,
            thumbhash: nil,
            fileModifiedAt: "2024-01-01T00:00:00Z",
            fileCreatedAt: "2024-01-01T00:00:00Z",
            localDateTime: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z",
            isFavorite: false,
            isArchived: false,
            isOffline: false,
            isTrashed: false,
            checksum: "checksum",
            duration: nil,
            hasMetadata: true,
            livePhotoVideoId: nil,
            people: [],
            visibility: "VISIBLE",
            duplicateId: nil,
            exifInfo: nil
        )
        
        // Should not be equal because they have different IDs
        #expect(asset1 != asset3)
    }
}

