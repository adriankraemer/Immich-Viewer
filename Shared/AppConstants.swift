//
//  AppConstants.swift
//  Immich-AppleTV
//
//  Created by Adrian Kraemer on 2025-08-12.
//

import Foundation

struct AppConstants {
    static let appGroupIdentifier = "group.app.immich.photo"
}

struct UserDefaultsKeys {
    // Immich credentials
    static let serverURL = "immich_server_url"
    static let accessToken = "immich_access_token"
    static let userEmail = "immich_user_email"
    static let userPrefix = "immich_user_"
    
    // Settings
    static let hideImageOverlay = "hideImageOverlay"
    static let slideshowInterval = "slideshowInterval"
    static let autoSlideshowTimeout = "autoSlideshowTimeout" // in minutes, 0 = off
    static let slideshowBackgroundColor = "slideshowBackgroundColor"
    static let showTagsTab = "showTagsTab"
    static let showFoldersTab = "showFoldersTab"
    static let showAlbumsTab = "showAlbumsTab"
    static let use24HourClock = "use24HourClock"
    static let enableReflectionsInSlideshow = "enableReflectionsInSlideshow"
    static let enableKenBurnsEffect = "enableKenBurnsEffect"
    static let enableThumbnailAnimation = "enableThumbnailAnimation"
    static let enableSlideshowShuffle = "enableSlideshowShuffle"
    static let allPhotosSortOrder = "allPhotosSortOrder"
    static let navigationStyle = "navigationStyle"
    static let enableTopShelf = "enableTopShelf"
    static let topShelfStyle = "topShelfStyle"
    static let topShelfImageSelection = "topShelfImageSelection"
    static let defaultStartupTab = "defaultStartupTab"
    static let lastSeenVersion = "lastSeenVersion"
    static let assetSortOrder = "assetSortOrder"
}

struct AppSchemes {
    static let immichGallery = "immichgallery"
}

struct NotificationNames {
    static let openAsset = "OpenAsset"
    static let refreshAllTabs = "refreshAllTabs"
    static let startAutoSlideshow = "startAutoSlideshow"
}
