import SwiftUI

@main
struct Immich_ViewerApp: App {
    init() {
        UserDefaults.standard.register(defaults: [
            UserDefaultsKeys.hideImageOverlay: true,
            UserDefaultsKeys.showAlbumsTab: true,
            UserDefaultsKeys.use24HourClock: true,
            UserDefaultsKeys.enableFadeOnlyEffect: true,
            UserDefaultsKeys.slideshowInterval: 8.0,
            UserDefaultsKeys.slideshowBackgroundColor: "ambilight",
            UserDefaultsKeys.allPhotosSortOrder: "desc",
            UserDefaultsKeys.albumListSortOrder: "alphabetical",
            UserDefaultsKeys.folderViewMode: "timeline",
            UserDefaultsKeys.exploreViewMode: "places",
            UserDefaultsKeys.defaultStartupTab: "photos"
        ])
        
        UserDefaults(suiteName: AppConstants.appGroupIdentifier)?.register(defaults: [
            UserDefaultsKeys.enableTopShelf: true,
            UserDefaultsKeys.topShelfStyle: "carousel",
            UserDefaultsKeys.topShelfImageSelection: "recent"
        ])
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleURL(url)
                }
        }
    }
    
    /// Handles deep link URLs to open specific assets
    /// Supports format: immichgallery://asset/{assetId}
    private func handleURL(_ url: URL) {
        guard url.scheme == AppSchemes.immichGallery else { return }
        
        // Parse asset deep link: immichgallery://asset/{assetId}
        if url.host == "asset", url.pathComponents.count > 1 {
            let assetId = url.pathComponents[1]
            
            // Post notification to ContentView to handle asset opening
            NotificationCenter.default.post(
                name: NSNotification.Name(NotificationNames.openAsset),
                object: nil,
                userInfo: ["assetId": assetId]
            )
        }
    }
}
