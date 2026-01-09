import SwiftUI

struct DisplaySettingsView: View {
    @AppStorage("showTagsTab") private var showTagsTab = false
    @AppStorage("showFoldersTab") private var showFoldersTab = false
    @AppStorage("showAlbumsTab") private var showAlbumsTab = true
    @AppStorage("defaultStartupTab") private var defaultStartupTab = "photos"
    @AppStorage("assetSortOrder") private var assetSortOrder = "desc"
    @AppStorage("allPhotosSortOrder") private var allPhotosSortOrder = "desc"
    @AppStorage("navigationStyle") private var navigationStyle = NavigationStyle.tabs.rawValue
    @AppStorage("folderViewMode") private var folderViewMode = "timeline"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                SettingsSection(title: String(localized: "Interface")) {
                    AnyView(VStack(spacing: 12) {
                        SettingsRow(
                            icon: "tag",
                            title: String(localized: "Show Tags Tab"),
                            subtitle: String(localized: "Enable the tags tab in the main navigation"),
                            content: AnyView(Toggle("", isOn: $showTagsTab).labelsHidden()),
                            isOn: showTagsTab
                        )
                        SettingsRow(
                            icon: "folder",
                            title: String(localized: "Show Albums Tab"),
                            subtitle: String(localized: "Enable the albums tab in the main navigation"),
                            content: AnyView(Toggle("", isOn: $showAlbumsTab).labelsHidden()),
                            isOn: showAlbumsTab
                        )
                        SettingsRow(
                            icon: "folder.fill",
                            title: String(localized: "Show Folders Tab"),
                            subtitle: String(localized: "Enable the folders tab in the main navigation"),
                            content: AnyView(Toggle("", isOn: $showFoldersTab).labelsHidden()),
                            isOn: showFoldersTab
                        )
                        SettingsRow(
                            icon: "house",
                            title: String(localized: "Default Startup Tab"),
                            subtitle: String(localized: "Choose which tab opens when the app starts"),
                            content: AnyView(
                                Picker(String(localized: "Default Tab"), selection: $defaultStartupTab) {
                                    Text(String(localized: "All Photos")).tag("photos")
                                    if showAlbumsTab {
                                        Text(String(localized: "Albums")).tag("albums")
                                    }
                                    Text(String(localized: "People")).tag("people")
                                    if showTagsTab {
                                        Text(String(localized: "Tags")).tag("tags")
                                    }
                                    if showFoldersTab {
                                        Text(String(localized: "Folders")).tag("folders")
                                    }
                                    Text(String(localized: "Explore")).tag("explore")
                                }
                                    .pickerStyle(.menu)
                                    .frame(width: 300, alignment: .trailing)
                            )
                        )
                        
                        SettingsRow(
                            icon: "rectangle.split.3x1",
                            title: String(localized: "Navigation Style"),
                            subtitle: String(localized: "Choose between a classic tab bar or the adaptive sidebar layout"),
                            content: AnyView(
                                Picker(String(localized: "Navigation Style"), selection: Binding(
                                    get: { NavigationStyle(rawValue: navigationStyle) ?? .tabs },
                                    set: { navigationStyle = $0.rawValue }
                                )) {
                                    ForEach(NavigationStyle.allCases, id: \.self) { style in
                                        Text(style.localizedDisplayName).tag(style)
                                    }
                                }
                                    .pickerStyle(.menu)
                                    .frame(width: 300, alignment: .trailing)
                            )
                        )
                        
                        if showFoldersTab {
                            SettingsRow(
                                icon: "list.bullet.indent",
                                title: String(localized: "Folder View Mode"),
                                subtitle: String(localized: "Choose how folders are displayed in the Folders tab"),
                                content: AnyView(
                                    Picker(String(localized: "Folder View"), selection: $folderViewMode) {
                                        Text(String(localized: "Grid")).tag("grid")
                                        Text(String(localized: "Tree")).tag("tree")
                                        Text(String(localized: "Timeline")).tag("timeline")
                                    }
                                        .pickerStyle(.menu)
                                        .frame(width: 300, alignment: .trailing)
                                )
                            )
                        }
                    })
                }
                
                SettingsSection(title: String(localized: "Sorting")) {
                    AnyView(VStack(spacing: 12) {
                        SettingsRow(
                            icon: "photo.on.rectangle",
                            title: String(localized: "All Photos Sort Order"),
                            subtitle: String(localized: "Order photos in the All Photos tab"),
                            content: AnyView(
                                Picker(String(localized: "All Photos Sort Order"), selection: $allPhotosSortOrder) {
                                    Text(String(localized: "Newest First")).tag("desc")
                                    Text(String(localized: "Oldest First")).tag("asc")
                                }
                                    .pickerStyle(.menu)
                                    .frame(width: 300, alignment: .trailing)
                            )
                        )
                        
                        SettingsRow(
                            icon: "arrow.up.arrow.down",
                            title: String(localized: "Albums & Collections Sort Order"),
                            subtitle: String(localized: "Order photos in Albums, People, and Tags"),
                            content: AnyView(
                                Picker(String(localized: "Collections Sort Order"), selection: $assetSortOrder) {
                                    Text(String(localized: "Newest First")).tag("desc")
                                    Text(String(localized: "Oldest First")).tag("asc")
                                }
                                    .pickerStyle(.menu)
                                    .frame(width: 300, alignment: .trailing)
                            )
                        )
                    })
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
        }
        .onChange(of: showAlbumsTab) { _, newValue in
            if !newValue && defaultStartupTab == "albums" {
                defaultStartupTab = "photos"
            }
        }
        .onChange(of: showFoldersTab) { _, newValue in
            if !newValue && defaultStartupTab == "folders" {
                defaultStartupTab = "photos"
            }
        }
    }
}

