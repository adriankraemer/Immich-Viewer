//
//  Immich_AppleTVApp.swift
//  Immich-AppleTV
//
//  Created by Adrian Kraemer on 2025-06-29.
//

import SwiftUI

@main
struct Immich_AppleTVApp: App {
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
