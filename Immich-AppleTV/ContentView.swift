//
//  ContentView.swift
//  Immich-AppleTV
//
//  Created by Adrian Kraemer on 2025-06-29.
//

import SwiftUI

/// Enumeration of all available tabs in the app
enum TabName: Int, CaseIterable {
    case photos = 0
    case albums = 1
    case people = 2
    case tags = 3
    case folders = 4
    case explore = 5
    case worldMap = 6
    case search = 7
    case settings = 8
    
    var title: String {
        switch self {
        case .photos: return "Photos"
        case .albums: return "Albums"
        case .people: return "People"
        case .tags: return "Tags"
        case .folders: return "Folders"
        case .explore: return "Explore"
        case .worldMap: return "WorldMap"
        case .search: return "Search"
        case .settings: return "Settings"
        }
    }
    
    var iconName: String {
        switch self {
        case .photos: return "photo.on.rectangle"
        case .albums: return "folder"
        case .people: return "person.crop.circle"
        case .tags: return "tag"
        case .folders: return "folder.fill"
        case .explore: return "globe"
        case .worldMap: return "map"
        case .search: return "magnifyingglass"
        case .settings: return "gear"
        }
    }
}

extension Notification.Name {
    static let refreshAllTabs = Notification.Name(NotificationNames.refreshAllTabs)
}

struct ContentView: View {
    // MARK: - Auto Slideshow State
    /// Timeout in minutes before auto-slideshow starts (0 = disabled)
    @AppStorage(UserDefaultsKeys.autoSlideshowTimeout) private var autoSlideshowTimeout: Int = 0
    @State private var inactivityTimer: Timer? = nil
    @State private var lastInteractionDate = Date()
    @StateObject private var userManager = UserManager()
    @StateObject private var networkService: NetworkService
    @StateObject private var authService: AuthenticationService
    @StateObject private var assetService: AssetService
    @StateObject private var albumService: AlbumService
    @StateObject private var peopleService: PeopleService
    @StateObject private var tagService: TagService
    @StateObject private var folderService: FolderService
    @StateObject private var exploreService: ExploreService
    @StateObject private var mapService: MapService
    @StateObject private var searchService: SearchService
    // MARK: - Tab Management
    @State private var selectedTab = 0
    /// UUID used to force refresh of all tabs when changed
    @State private var refreshTrigger = UUID()
    @AppStorage(UserDefaultsKeys.showTagsTab) private var showTagsTab = false
    @AppStorage(UserDefaultsKeys.showFoldersTab) private var showFoldersTab = false
    @AppStorage(UserDefaultsKeys.showAlbumsTab) private var showAlbumsTab = true
    @AppStorage(UserDefaultsKeys.defaultStartupTab) private var defaultStartupTab = "photos"
    @AppStorage(UserDefaultsKeys.navigationStyle) private var navigationStyle = NavigationStyle.tabs.rawValue
    @State private var searchTabHighlighted = false
    /// Asset ID from deep link to highlight when opening Photos tab
    @State private var deepLinkAssetId: String?
    
    init() {
        let userManager = UserManager()
        let networkService = NetworkService(userManager: userManager)
        _userManager = StateObject(wrappedValue: userManager)
        _networkService = StateObject(wrappedValue: networkService)
        _authService = StateObject(wrappedValue: AuthenticationService(networkService: networkService, userManager: userManager))
        _assetService = StateObject(wrappedValue: AssetService(networkService: networkService))
        _albumService = StateObject(wrappedValue: AlbumService(networkService: networkService))
        _peopleService = StateObject(wrappedValue: PeopleService(networkService: networkService))
        _tagService = StateObject(wrappedValue: TagService(networkService: networkService))
        _folderService = StateObject(wrappedValue: FolderService(networkService: networkService))
        _exploreService = StateObject(wrappedValue: ExploreService(networkService: networkService))
        _mapService = StateObject(wrappedValue: MapService(networkService: networkService))
        _searchService = StateObject(wrappedValue: SearchService(networkService: networkService))
    }
    
    private var currentNavigationStyle: NavigationStyle {
        NavigationStyle(rawValue: navigationStyle) ?? .tabs
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if !authService.isAuthenticated {
                    // Show sign-in view
                    SignInView(authService: authService, userManager: userManager, mode: .signIn)
                        .errorBoundary(context: "Authentication")
                } else {
                    // Main app interface
                    TabView(selection: $selectedTab) {
                        AssetGridView(
                            assetService: assetService, 
                            authService: authService, 
                            assetProvider: AssetProviderFactory.createProvider(
                                isAllPhotos: true,
                                assetService: assetService
                            ),
                            albumId: nil, personId: nil, tagId: nil, city: nil, isAllPhotos: true, isFavorite: false,
                            onAssetsLoaded: nil, 
                            deepLinkAssetId: deepLinkAssetId
                        )
                        .errorBoundary(context: "Photos Tab")
                        .tabItem {
                            Image(systemName: TabName.photos.iconName)
                            Text(TabName.photos.title)
                        }
                        .tag(TabName.photos.rawValue)
                        
                        if showAlbumsTab {
                            AlbumListView(albumService: albumService, authService: authService, assetService: assetService, userManager: userManager)
                                .errorBoundary(context: "Albums Tab")
                                .tabItem {
                                    Image(systemName: TabName.albums.iconName)
                                    Text(TabName.albums.title)
                                }
                                .tag(TabName.albums.rawValue)
                        }
                        
                        PeopleGridView(peopleService: peopleService, authService: authService, assetService: assetService)
                            .errorBoundary(context: "People Tab")
                            .tabItem {
                                Image(systemName: TabName.people.iconName)
                                Text(TabName.people.title)
                            }
                            .tag(TabName.people.rawValue)
                        
                        if showTagsTab {
                            TagsGridView(tagService: tagService, authService: authService, assetService: assetService)
                                .errorBoundary(context: "Tags Tab")
                                .tabItem {
                                    Image(systemName: TabName.tags.iconName)
                                    Text(TabName.tags.title)
                                }
                                .tag(TabName.tags.rawValue)
                        }

                        if showFoldersTab {
                            FoldersView(folderService: folderService, assetService: assetService, authService: authService)
                                .errorBoundary(context: "Folders Tab")
                                .tabItem {
                                    Image(systemName: TabName.folders.iconName)
                                    Text(TabName.folders.title)
                                }
                                .tag(TabName.folders.rawValue)
                        }
                        
                        ExploreView(exploreService: exploreService, assetService: assetService, authService: authService, userManager: userManager)
                            .errorBoundary(context: "Explore Tab")
                            .tabItem {
                                Image(systemName: TabName.explore.iconName)
                                Text(TabName.explore.title)
                            }
                            .tag(TabName.explore.rawValue)
                        
                        WorldMapView(mapService: mapService, assetService: assetService, authService: authService)
                            .errorBoundary(context: "WorldMap Tab")
                            .tabItem {
                                Image(systemName: TabName.worldMap.iconName)
                                Text(TabName.worldMap.title)
                            }
                            .tag(TabName.worldMap.rawValue)
                        
                        SearchView(searchService: searchService, assetService: assetService, authService: authService)
                            .errorBoundary(context: "Search Tab")
                            .tabItem {
                                Image(systemName: TabName.search.iconName)
                                Text(TabName.search.title)
                            }
                            .tag(TabName.search.rawValue)
                        
                        SettingsView(authService: authService, userManager: userManager)
                            .errorBoundary(context: "Settings Tab")
                            .tabItem {
                                Image(systemName: TabName.settings.iconName)
                                Text(TabName.settings.title)
                            }
                            .tag(TabName.settings.rawValue)
                    }
                    .tabNavigationStyle(currentNavigationStyle)
                    .onAppear {
                        setDefaultTab()
                        startInactivityTimer()
                    }
                    .onChange(of: selectedTab) { oldValue, newValue in
                        searchTabHighlighted = false
                        resetInactivityTimer()
                    }
                    .onChange(of: autoSlideshowTimeout) { _, _ in
                        startInactivityTimer()
                    }
                    .onChange(of: showAlbumsTab) { _, enabled in
                        // Switch to Photos tab if Albums tab is disabled while user is viewing it
                        if !enabled && selectedTab == TabName.albums.rawValue {
                            selectedTab = TabName.photos.rawValue
                        }
                    }
                    .onChange(of: showFoldersTab) { _, enabled in
                        // Switch to Photos tab if Folders tab is disabled while user is viewing it
                        if !enabled && selectedTab == TabName.folders.rawValue {
                            selectedTab = TabName.photos.rawValue
                        }
                    }
                    /// Force refresh when refreshTrigger changes (used by refreshAllTabs notification)
                    .id(refreshTrigger)
                    // .accentColor(.blue)
                }
            }
            .navigationTitle("Immich-AppleTV")
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onReceive(NotificationCenter.default.publisher(for: .refreshAllTabs)) { _ in
            // Refresh all tabs by generating a new UUID (triggers view refresh via .id modifier)
            refreshTrigger = UUID()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name(NotificationNames.openAsset))) { notification in
            // Handle deep link to open a specific asset
            if let assetId = notification.userInfo?["assetId"] as? String {
                debugLog("ContentView: Received OpenAsset notification for asset: \(assetId)")
                
                // Switch to Photos tab and set deep link asset ID for highlighting
                selectedTab = TabName.photos.rawValue
                deepLinkAssetId = assetId
                
                // Clear deep link after 1 second to prevent stale state
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    deepLinkAssetId = nil
                }
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded { resetInactivityTimer() }
        )
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("stopAutoSlideshowTimer"))) { _ in
            debugLog("ContentView: Stopping auto-slideshow timer")
            inactivityTimer?.invalidate()
            inactivityTimer = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("restartAutoSlideshowTimer"))) { _ in
            debugLog("ContentView: Restarting auto-slideshow timer")
            resetInactivityTimer()
        }
    }
    
    // MARK: - Inactivity Timer Logic
    
    /// Starts the inactivity timer that triggers auto-slideshow after timeout
    private func startInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
        if autoSlideshowTimeout > 0 {
            debugLog("ContentView: Starting inactivity timer with timeout: \(autoSlideshowTimeout) minutes")
            // Check every second if timeout has been reached
            inactivityTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                let elapsed = Date().timeIntervalSince(lastInteractionDate)
                if elapsed > Double(autoSlideshowTimeout * 60) {
                    debugLog("ContentView: Auto-slideshow timeout reached! Elapsed: \(elapsed) seconds")
                    inactivityTimer?.invalidate()
                    inactivityTimer = nil
                    // Switch to Photos tab and start auto slideshow
                    selectedTab = TabName.photos.rawValue
                    // Wait 5 seconds for tab switch animation to complete before starting slideshow
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        NotificationCenter.default.post(name: NSNotification.Name(NotificationNames.startAutoSlideshow), object: nil)
                    }
                }
            }
        } else {
            debugLog("ContentView: Auto-slideshow disabled (timeout = 0)")
        }
    }
    
    /// Resets the inactivity timer when user interacts with the app
    
    private func resetInactivityTimer() {
        debugLog("ContentView: Resetting inactivity timer")
        lastInteractionDate = Date()
        startInactivityTimer() // Restart the timer
    }
    
    /// Sets the initial tab based on user preference, falling back to Photos if preferred tab is disabled
    private func setDefaultTab() {
        switch defaultStartupTab {
        case "photos":
            selectedTab = TabName.photos.rawValue
        case "albums":
            if showAlbumsTab {
                selectedTab = TabName.albums.rawValue
            } else {
                selectedTab = TabName.photos.rawValue
            }
        case "people":
            selectedTab = TabName.people.rawValue
        case "tags":
            if showTagsTab {
                selectedTab = TabName.tags.rawValue
            } else {
                // Default to photos if tags tab is disabled
                selectedTab = TabName.photos.rawValue
            }
        case "folders":
            if showFoldersTab {
                selectedTab = TabName.folders.rawValue
            } else {
                selectedTab = TabName.photos.rawValue
            }
        case "explore":
            selectedTab = TabName.explore.rawValue
        case "worldmap":
            selectedTab = TabName.worldMap.rawValue
        case "search":
            selectedTab = TabName.search.rawValue
        case "settings":
            selectedTab = TabName.settings.rawValue
        default:
            selectedTab = TabName.photos.rawValue
        }
    }
}

/// View modifier to apply different navigation styles to TabView
private struct TabNavigationStyleModifier: ViewModifier {
    let style: NavigationStyle
    
    func body(content: Content) -> some View {
        switch style {
        case .sidebar:
            // Use sidebar style for Apple TV (more traditional navigation)
            content.tabViewStyle(.sidebarAdaptable)
        case .tabs:
            // Use default tab style
            content
        }
    }
}

private extension View {
    func tabNavigationStyle(_ style: NavigationStyle) -> some View {
        modifier(TabNavigationStyleModifier(style: style))
    }
}

#Preview {
    ContentView()
}
