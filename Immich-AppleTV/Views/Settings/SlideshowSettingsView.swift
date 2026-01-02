import SwiftUI

struct SlideshowSettingsView: View {
    @AppStorage("hideImageOverlay") private var hideImageOverlay = true
    @State private var slideshowInterval: Double = UserDefaults.standard.object(forKey: "slideshowInterval") as? Double ?? 8.0
    @AppStorage("slideshowBackgroundColor") private var slideshowBackgroundColor = "ambilight"
    @AppStorage("use24HourClock") private var use24HourClock = true
    @AppStorage("enableReflectionsInSlideshow") private var enableReflectionsInSlideshow = true
    @AppStorage("enableKenBurnsEffect") private var enableKenBurnsEffect = false
    @AppStorage("enableSlideshowShuffle") private var enableSlideshowShuffle = false
    @AppStorage(UserDefaultsKeys.autoSlideshowTimeout) private var autoSlideshowTimeout: Int = 0
    @FocusState private var isMinusFocused: Bool
    @FocusState private var isPlusFocused: Bool
    @FocusState private var focusedColor: String?
    
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
                            enableShuffle: $enableSlideshowShuffle,
                            autoSlideshowTimeout: $autoSlideshowTimeout,
                            isMinusFocused: $isMinusFocused,
                            isPlusFocused: $isPlusFocused,
                            focusedColor: $focusedColor
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
    }
}

