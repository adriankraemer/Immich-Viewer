import SwiftUI

struct TopShelfSettingsView: View {
    @AppStorage("enableTopShelf", store: UserDefaults(suiteName: AppConstants.appGroupIdentifier)) private var enableTopShelf = true
    @AppStorage("topShelfStyle", store: UserDefaults(suiteName: AppConstants.appGroupIdentifier)) private var topShelfStyle = "carousel"
    @AppStorage("topShelfImageSelection", store: UserDefaults(suiteName: AppConstants.appGroupIdentifier)) private var topShelfImageSelection = "recent"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                SettingsSection(title: "Top Shelf") {
                    AnyView(VStack(spacing: 12) {
                        SettingsRow(
                            icon: "tv",
                            title: "Top Shelf Extension",
                            subtitle: "Choose display style or disable Top Shelf entirely (Top shelf does not show portrait images)",
                            content: AnyView(
                                Picker("Top Shelf", selection: Binding(
                                    get: { enableTopShelf ? topShelfStyle : "off" },
                                    set: { newValue in
                                        if newValue == "off" {
                                            enableTopShelf = false
                                        } else {
                                            enableTopShelf = true
                                            topShelfStyle = newValue
                                        }
                                    }
                                )) {
                                    Text(LocalizedStringResource("Off")).tag("off")
                                    Text(LocalizedStringResource("Compact")).tag("sectioned")
                                    Text(LocalizedStringResource("Fullscreen")).tag("carousel")
                                }
                                    .pickerStyle(.menu)
                                    .frame(width: 300, alignment: .trailing)
                            ),
                            isOn: enableTopShelf
                        )
                        
                        if enableTopShelf {
                            SettingsRow(
                                icon: "photo.on.rectangle.angled",
                                title: "Image Selection",
                                subtitle: "Choose between recent photos or random photos from your library.",
                                content: AnyView(
                                    Picker(String(localized: "Image Selection"), selection: $topShelfImageSelection) {
                                        Text(LocalizedStringResource("Recent Photos")).tag("recent")
                                        Text(LocalizedStringResource("Random Photos")).tag("random")
                                    }
                                        .pickerStyle(.menu)
                                        .frame(width: 500, alignment: .trailing)
                                )
                            )
                        }
                    })
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
        }
    }
}

