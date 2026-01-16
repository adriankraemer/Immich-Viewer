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
    
    var showWorldMapTab: Bool {
        get { bool(forKey: UserDefaultsKeys.showWorldMapTab) }
        set { set(newValue, forKey: UserDefaultsKeys.showWorldMapTab) }
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
    
    var enableFadeOnlyEffect: Bool {
        get { 
            if object(forKey: UserDefaultsKeys.enableFadeOnlyEffect) == nil {
                return true // Default to true for fresh installs
            }
            return bool(forKey: UserDefaultsKeys.enableFadeOnlyEffect)
        }
        set { set(newValue, forKey: UserDefaultsKeys.enableFadeOnlyEffect) }
    }
    
    var enableSlideshowShuffle: Bool {
        get { bool(forKey: UserDefaultsKeys.enableSlideshowShuffle) }
        set { set(newValue, forKey: UserDefaultsKeys.enableSlideshowShuffle) }
    }
    
    var allPhotosSortOrder: String {
        get { string(forKey: UserDefaultsKeys.allPhotosSortOrder) ?? "desc" }
        set { set(newValue, forKey: UserDefaultsKeys.allPhotosSortOrder) }
    }
    
    var folderViewMode: String {
        get { string(forKey: UserDefaultsKeys.folderViewMode) ?? "timeline" }
        set { set(newValue, forKey: UserDefaultsKeys.folderViewMode) }
    }
    
    var exploreViewMode: String {
        get { string(forKey: UserDefaultsKeys.exploreViewMode) ?? "places" }
        set { set(newValue, forKey: UserDefaultsKeys.exploreViewMode) }
    }
    
    var slideshowAlbumId: String? {
        get { string(forKey: UserDefaultsKeys.slideshowAlbumId) }
        set { set(newValue, forKey: UserDefaultsKeys.slideshowAlbumId) }
    }
    
    var slideshowAlbumName: String? {
        get { string(forKey: UserDefaultsKeys.slideshowAlbumName) }
        set { set(newValue, forKey: UserDefaultsKeys.slideshowAlbumName) }
    }
}
