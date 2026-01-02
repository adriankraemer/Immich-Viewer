import Foundation
// Extension to make overlay setting easily accessible throughout the app
extension UserDefaults {
    var autoSlideshowTimeout: Int {
        get {
            let value = integer(forKey: UserDefaultsKeys.autoSlideshowTimeout)
            return value >= 0 ? value : 0 // 0 = off
        }
        set { set(newValue, forKey: UserDefaultsKeys.autoSlideshowTimeout) }
    }
    var hideImageOverlay: Bool {
        get { bool(forKey: UserDefaultsKeys.hideImageOverlay) }
        set { set(newValue, forKey: UserDefaultsKeys.hideImageOverlay) }
    }
    
    var slideshowInterval: TimeInterval {
        get { 
            let value = double(forKey: UserDefaultsKeys.slideshowInterval)
            return value > 0 ? value : 6.0
        }
        set { set(newValue, forKey: UserDefaultsKeys.slideshowInterval) }
    }
    
    var slideshowBackgroundColor: String {
        get { string(forKey: UserDefaultsKeys.slideshowBackgroundColor) ?? "ambilight" }
        set { set(newValue, forKey: UserDefaultsKeys.slideshowBackgroundColor) }
    }
    
    var showTagsTab: Bool {
        get { bool(forKey: UserDefaultsKeys.showTagsTab) }
        set { set(newValue, forKey: UserDefaultsKeys.showTagsTab) }
    }
    
    var showFoldersTab: Bool {
        get { bool(forKey: UserDefaultsKeys.showFoldersTab) }
        set { set(newValue, forKey: UserDefaultsKeys.showFoldersTab) }
    }
    
    var showAlbumsTab: Bool {
        get { bool(forKey: UserDefaultsKeys.showAlbumsTab) }
        set { set(newValue, forKey: UserDefaultsKeys.showAlbumsTab) }
    }
    
    var use24HourClock: Bool {
        get { bool(forKey: UserDefaultsKeys.use24HourClock) }
        set { set(newValue, forKey: UserDefaultsKeys.use24HourClock) }
    }
    
    var enableReflectionsInSlideshow: Bool {
        get { bool(forKey: UserDefaultsKeys.enableReflectionsInSlideshow) }
        set { set(newValue, forKey: UserDefaultsKeys.enableReflectionsInSlideshow) }
    }
    
    var enableKenBurnsEffect: Bool {
        get { bool(forKey: UserDefaultsKeys.enableKenBurnsEffect) }
        set { set(newValue, forKey: UserDefaultsKeys.enableKenBurnsEffect) }
    }
    
    var enableThumbnailAnimation: Bool {
        get { 
            // Default to true if the key doesn't exist yet
            if object(forKey: UserDefaultsKeys.enableThumbnailAnimation) == nil {
                return true
            }
            return bool(forKey: UserDefaultsKeys.enableThumbnailAnimation)
        }
        set { set(newValue, forKey: UserDefaultsKeys.enableThumbnailAnimation) }
    }
    
    var enableSlideshowShuffle: Bool {
        get { bool(forKey: UserDefaultsKeys.enableSlideshowShuffle) }
        set { set(newValue, forKey: UserDefaultsKeys.enableSlideshowShuffle) }
    }
    
    var navigationStyle: String {
        get { string(forKey: UserDefaultsKeys.navigationStyle) ?? NavigationStyle.tabs.rawValue }
        set { set(newValue, forKey: UserDefaultsKeys.navigationStyle) }
    }
    
    var allPhotosSortOrder: String {
        get { string(forKey: UserDefaultsKeys.allPhotosSortOrder) ?? "desc" }
        set { set(newValue, forKey: UserDefaultsKeys.allPhotosSortOrder) }
    }
}
