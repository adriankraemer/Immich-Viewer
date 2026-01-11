import Foundation

/// App-wide constants
struct AppConstants {
    /// App group identifier for sharing data between main app and TopShelf extension
    static let appGroupIdentifier = "group.app.immich.photo"
}

/// Keys used for UserDefaults storage
struct UserDefaultsKeys {
    // MARK: - Immich Credentials (Legacy - now using multi-user storage)
    static let serverURL = "immich_server_url"
    static let accessToken = "immich_access_token"
    static let userEmail = "immich_user_email"
    /// Prefix for user data keys (format: "immich_user_{userId}")
    static let userPrefix = "immich_user_"
    
    // MARK: - Settings
    static let hideImageOverlay = "hideImageOverlay"
    static let slideshowInterval = "slideshowInterval"
    static let autoSlideshowTimeout = "autoSlideshowTimeout" // in minutes, 0 = off
    static let slideshowBackgroundColor = "slideshowBackgroundColor"
    static let showTagsTab = "showTagsTab"
    static let showFoldersTab = "showFoldersTab"
    static let showAlbumsTab = "showAlbumsTab"
    static let showWorldMapTab = "showWorldMapTab"
    static let use24HourClock = "use24HourClock"
    static let enableReflectionsInSlideshow = "enableReflectionsInSlideshow"
    static let enableKenBurnsEffect = "enableKenBurnsEffect"
    static let enableSlideshowShuffle = "enableSlideshowShuffle"
    static let allPhotosSortOrder = "allPhotosSortOrder"
    static let enableTopShelf = "enableTopShelf"
    static let topShelfStyle = "topShelfStyle"
    static let topShelfImageSelection = "topShelfImageSelection"
    static let defaultStartupTab = "defaultStartupTab"
    static let lastSeenVersion = "lastSeenVersion"
    static let assetSortOrder = "assetSortOrder"
    static let folderViewMode = "folderViewMode"
    static let exploreViewMode = "exploreViewMode"
}

/// URL schemes supported by the app for deep linking
struct AppSchemes {
    static let immichGallery = "immichgallery"
}

/// Notification names used for app-wide communication
struct NotificationNames {
    /// Notification to open a specific asset (userInfo: ["assetId": String])
    static let openAsset = "OpenAsset"
    /// Notification to refresh all tabs
    static let refreshAllTabs = "refreshAllTabs"
    /// Notification to start auto-slideshow
    static let startAutoSlideshow = "startAutoSlideshow"
}
