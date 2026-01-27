import SwiftUI

struct SlideshowSettingsView: View {
    // MARK: - Services
    @ObservedObject var albumService: AlbumService
    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    
    // MARK: - Settings Storage
    @AppStorage("hideImageOverlay") private var hideImageOverlay = true
    @State private var slideshowInterval: Double = UserDefaults.standard.object(forKey: "slideshowInterval") as? Double ?? 8.0
    @AppStorage("slideshowBackgroundColor") private var slideshowBackgroundColor = "ambilight"
    @AppStorage("use24HourClock") private var use24HourClock = true
    @AppStorage("enableReflectionsInSlideshow") private var enableReflectionsInSlideshow = false
    @AppStorage("enableKenBurnsEffect") private var enableKenBurnsEffect = false
    @AppStorage("enableFadeOnlyEffect") private var enableFadeOnlyEffect = true
    @AppStorage("enableSlideshowShuffle") private var enableSlideshowShuffle = false
    @AppStorage(UserDefaultsKeys.autoSlideshowTimeout) private var autoSlideshowTimeout: Int = 0
    @AppStorage(UserDefaultsKeys.slideshowAlbumId) private var slideshowAlbumId: String = ""
    @AppStorage(UserDefaultsKeys.slideshowAlbumName) private var slideshowAlbumName: String = ""
    
    // MARK: - Focus State
    @FocusState private var isMinusFocused: Bool
    @FocusState private var isPlusFocused: Bool
    @FocusState private var focusedColor: String?
    
    // MARK: - Sheet State
    @State private var showingAlbumPicker = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                SettingsSection(title: "Slideshow") {
                    AnyView(VStack(spacing: 12) {
                        SlideshowSettings(
                            slideshowInterval: $slideshowInterval,
                            slideshowBackgroundColor: $slideshowBackgroundColor,
                            use24HourClock: $use24HourClock,
                            hideOverlay: $hideImageOverlay,
                            enableReflections: $enableReflectionsInSlideshow,
                            enableKenBurns: $enableKenBurnsEffect,
                            enableFadeOnly: $enableFadeOnlyEffect,
                            enableShuffle: $enableSlideshowShuffle,
                            autoSlideshowTimeout: $autoSlideshowTimeout,
                            slideshowAlbumId: $slideshowAlbumId,
                            slideshowAlbumName: $slideshowAlbumName,
                            isMinusFocused: $isMinusFocused,
                            isPlusFocused: $isPlusFocused,
                            focusedColor: $focusedColor,
                            onShowAlbumPicker: {
                                showingAlbumPicker = true
                            }
                        )
                        .onChange(of: slideshowInterval) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "slideshowInterval")
                        }
                    })
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
        }
        .fullScreenCover(isPresented: $showingAlbumPicker) {
            SlideshowAlbumPicker(
                albumService: albumService,
                assetService: assetService,
                authService: authService,
                selectedAlbumId: $slideshowAlbumId,
                selectedAlbumName: $slideshowAlbumName
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name(NotificationNames.refreshAllTabs))) { _ in
            // Clear slideshow album selection on user switch (falls back to "All Photos")
            slideshowAlbumId = ""
            slideshowAlbumName = ""
        }
    }
}

