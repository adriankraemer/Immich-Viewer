import SwiftUI

struct DisplaySettingsView: View {
    @AppStorage("showTagsTab") private var showTagsTab = false
    @AppStorage("showFoldersTab") private var showFoldersTab = false
    @AppStorage("showAlbumsTab") private var showAlbumsTab = true
    @AppStorage("defaultStartupTab") private var defaultStartupTab = "photos"
    @AppStorage("assetSortOrder") private var assetSortOrder = "desc"
    @AppStorage("allPhotosSortOrder") private var allPhotosSortOrder = "desc"
    @AppStorage("folderViewMode") private var folderViewMode = "timeline"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                SettingsSection(title: "Interface") {
                    AnyView(VStack(spacing: 12) {
                        SettingsRow(
                            icon: "tag",
                            title: "Show Tags Tab",
                            subtitle: "Enable the tags tab in the main navigation",
                            content: AnyView(Toggle("", isOn: $showTagsTab).labelsHidden()),
                            isOn: showTagsTab
                        )
                        SettingsRow(
                            icon: "folder",
                            title: "Show Albums Tab",
                            subtitle: "Enable the albums tab in the main navigation",
                            content: AnyView(Toggle("", isOn: $showAlbumsTab).labelsHidden()),
                            isOn: showAlbumsTab
                        )
                        SettingsRow(
                            icon: "folder.fill",
                            title: "Show Folders Tab",
                            subtitle: "Enable the folders tab in the main navigation",
                            content: AnyView(Toggle("", isOn: $showFoldersTab).labelsHidden()),
                            isOn: showFoldersTab
                        )
                        SettingsRow(
                            icon: "house",
                            title: "Default Startup Tab",
                            subtitle: "Choose which tab opens when the app starts",
                            content: AnyView(
                                Picker("Default Tab", selection: $defaultStartupTab) {
                                    Text("All Photos").tag("photos")
                                    if showAlbumsTab {
                                        Text("Albums").tag("albums")
                                    }
                                    Text("People").tag("people")
                                    if showTagsTab {
                                        Text("Tags").tag("tags")
                                    }
                                    if showFoldersTab {
                                        Text("Folders").tag("folders")
                                    }
                                    Text("Explore").tag("explore")
                                }
                                    .pickerStyle(.menu)
                                    .frame(width: 300, alignment: .trailing)
                            )
                        )
                        
                        if showFoldersTab {
                            SettingsRow(
                                icon: "list.bullet.indent",
                                title: "Folder View Mode",
                                subtitle: "Choose how folders are displayed in the Folders tab",
                                content: AnyView(
                                    Picker("Folder View", selection: $folderViewMode) {
                                        Text("Grid").tag("grid")
                                        Text("Tree").tag("tree")
                                        Text("Timeline").tag("timeline")
                                    }
                                        .pickerStyle(.menu)
                                        .frame(width: 300, alignment: .trailing)
                                )
                            )
                        }
                    })
                }
                
                SettingsSection(title: "Sorting") {
                    AnyView(VStack(spacing: 12) {
                        SettingsRow(
                            icon: "photo.on.rectangle",
                            title: "All Photos Sort Order",
                            subtitle: "Order photos in the All Photos tab",
                            content: AnyView(
                                Picker("All Photos Sort Order", selection: $allPhotosSortOrder) {
                                    Text("Newest First").tag("desc")
                                    Text("Oldest First").tag("asc")
                                }
                                    .pickerStyle(.menu)
                                    .frame(width: 300, alignment: .trailing)
                            )
                        )
                        
                        SettingsRow(
                            icon: "arrow.up.arrow.down",
                            title: "Albums & Collections Sort Order",
                            subtitle: "Order photos in Albums, People, and Tags",
                            content: AnyView(
                                Picker("Collections Sort Order", selection: $assetSortOrder) {
                                    Text("Newest First").tag("desc")
                                    Text("Oldest First").tag("asc")
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
