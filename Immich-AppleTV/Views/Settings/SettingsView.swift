//
//  SettingsView.swift
//  Immich-AppleTV
//
//  Created by Adrian Kraemer on 2025-06-29.
//


import SwiftUI

// MARK: - Cinematic Theme Constants for Settings
private enum SettingsTheme {
    static let accent = Color(red: 245/255, green: 166/255, blue: 35/255)
    static let accentLight = Color(red: 255/255, green: 200/255, blue: 100/255)
    static let surface = Color(red: 30/255, green: 30/255, blue: 32/255)
    static let surfaceLight = Color(red: 45/255, green: 45/255, blue: 48/255)
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 142/255, green: 142/255, blue: 147/255)
    static let success = Color(red: 52/255, green: 199/255, blue: 89/255)
}

// MARK: - Reusable Components

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let content: AnyView
    let isOn: Bool
    
    init(icon: String, title: String, subtitle: String, content: AnyView, isOn: Bool = false) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.content = content
        self.isOn = isOn
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon with cinematic styling
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [
                                (isOn ? SettingsTheme.success : SettingsTheme.accent).opacity(0.2),
                                (isOn ? SettingsTheme.success : SettingsTheme.accent).opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .foregroundColor(isOn ? SettingsTheme.success : SettingsTheme.accent)
                    .font(.system(size: 20, weight: .medium))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(SettingsTheme.textPrimary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(SettingsTheme.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            content
        }
        .padding(20)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(SettingsTheme.surface.opacity(0.6))
                
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.05), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                isOn ? SettingsTheme.success.opacity(0.3) : Color.white.opacity(0.08),
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
    }
}

// MARK: - Main Settings View

struct SettingsView: View {
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var userManager: UserManager
    @State private var showingClearCacheAlert = false
    @State private var showingDeleteUserAlert = false
    @State private var userToDelete: SavedUser?
    @State private var showingSignIn = false
    @State private var showingStats = false
    @AppStorage("hideImageOverlay") private var hideImageOverlay = true
    @State private var slideshowInterval: Double = UserDefaults.standard.object(forKey: "slideshowInterval") as? Double ?? 8.0
    @AppStorage("slideshowBackgroundColor") private var slideshowBackgroundColor = "ambilight"
    @AppStorage("showTagsTab") private var showTagsTab = false
    @AppStorage("showFoldersTab") private var showFoldersTab = false
    @AppStorage("showAlbumsTab") private var showAlbumsTab = true
    @AppStorage("defaultStartupTab") private var defaultStartupTab = "photos"
    @AppStorage("assetSortOrder") private var assetSortOrder = "desc"
    @AppStorage("use24HourClock") private var use24HourClock = true
    @AppStorage("enableReflectionsInSlideshow") private var enableReflectionsInSlideshow = true
    @AppStorage("enableKenBurnsEffect") private var enableKenBurnsEffect = false
    @AppStorage("enableThumbnailAnimation") private var enableThumbnailAnimation = false
    @AppStorage("enableSlideshowShuffle") private var enableSlideshowShuffle = false
    @AppStorage("allPhotosSortOrder") private var allPhotosSortOrder = "desc"
    @AppStorage("navigationStyle") private var navigationStyle = NavigationStyle.tabs.rawValue
    @AppStorage("enableTopShelf", store: UserDefaults(suiteName: AppConstants.appGroupIdentifier)) private var enableTopShelf = true
    @AppStorage("topShelfStyle", store: UserDefaults(suiteName: AppConstants.appGroupIdentifier)) private var topShelfStyle = "carousel"
    @AppStorage("topShelfImageSelection", store: UserDefaults(suiteName: AppConstants.appGroupIdentifier)) private var topShelfImageSelection = "recent"
    @AppStorage(UserDefaultsKeys.autoSlideshowTimeout) private var autoSlideshowTimeout: Int = 0 // 0 = off
    @FocusState private var isMinusFocused: Bool
    @FocusState private var isPlusFocused: Bool
    @FocusState private var focusedColor: String?
    
    
    private var serverInfoSection: some View {
        Button(action: {
            refreshServerConnection()
        }) {
            HStack(spacing: 20) {
                // Server icon with cinematic styling
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    SettingsTheme.success.opacity(0.2),
                                    SettingsTheme.success.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: authService.baseURL.lowercased().hasPrefix("https") ? "lock.fill" : "lock.open.fill")
                        .foregroundColor(authService.baseURL.lowercased().hasPrefix("https") ? SettingsTheme.success : .red)
                        .font(.system(size: 32, weight: .medium))
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Connected Server")
                        .font(.subheadline)
                        .foregroundColor(SettingsTheme.textSecondary)
                    Text(authService.baseURL)
                        .font(.headline)
                        .foregroundColor(SettingsTheme.textPrimary)
                }
                
                Spacer()
                
                // Refresh button
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Refresh")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(SettingsTheme.accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(SettingsTheme.accent.opacity(0.15))
                )
                
                // Status indicator
                ZStack {
                    Circle()
                        .fill(SettingsTheme.success.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(SettingsTheme.success)
                }
            }
            .padding(24)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(SettingsTheme.surface.opacity(0.6))
                    
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.05), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [SettingsTheme.success.opacity(0.3), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
        }
        .buttonStyle(CardButtonStyle())
    }
    
    private var userActionsSection: some View {
        VStack(spacing: 16) {
            if userManager.savedUsers.count > 0 {
                ForEach(userManager.savedUsers, id: \.id) { user in
                    userRow(user: user)
                }
            }
            
            Button(action: {
                showingSignIn = true
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(SettingsTheme.accent.opacity(0.15))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(SettingsTheme.accent)
                    }
                    
                    Text("Add User")
                        .font(.headline)
                        .foregroundColor(SettingsTheme.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(SettingsTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(SettingsTheme.surface.opacity(0.6))
                        
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [SettingsTheme.accent.opacity(0.3), Color.white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                )
            }
            .buttonStyle(CardButtonStyle())
        }
    }
    
    private func userRow(user: SavedUser) -> some View {
        let accentColor = user.authType == .apiKey ? Color.orange : SettingsTheme.accent
        let isActive = userManager.currentUser?.id == user.id
        
        return HStack(spacing: 12) {
            Button(action: {
                switchToUser(user)
            }) {
                HStack(spacing: 16) {
                    ProfileImageView(
                        userId: user.id,
                        authType: user.authType,
                        size: 80,
                        profileImageData: user.profileImageData
                    )
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Badge(
                                user.authType == .apiKey ? "API Key" : "Password",
                                color: accentColor
                            )
                            
                            Text(user.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(SettingsTheme.textPrimary)
                        }
                        
                        Text(user.email)
                            .font(.subheadline)
                            .foregroundColor(SettingsTheme.textSecondary)
                        
                        Text(user.serverURL)
                            .font(.caption)
                            .foregroundColor(SettingsTheme.textSecondary.opacity(0.7))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    if isActive {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(SettingsTheme.success)
                                .frame(width: 8, height: 8)
                            Text("Active")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(SettingsTheme.success)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(SettingsTheme.success.opacity(0.15))
                        )
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(accentColor)
                            .font(.title2)
                    }
                }
                .padding(20)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(SettingsTheme.surface.opacity(0.6))
                        
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.05), Color.clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        isActive ? SettingsTheme.success.opacity(0.4) : accentColor.opacity(0.2),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isActive ? 1.5 : 1
                            )
                    }
                )
            }
            .buttonStyle(CardButtonStyle())
            
            Button(action: {
                userToDelete = user
                showingDeleteUserAlert = true
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 20, weight: .medium))
                }
            }
            .buttonStyle(CardButtonStyle())
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                SharedGradientBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 30) {
                        
                        serverInfoSection
                        userActionsSection
                        
                        // Interface Settings Section
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
                                        icon: "play.rectangle.on.rectangle",
                                        title: "Enable Thumbnail Animation",
                                        subtitle: "Animate thumbnails in Albums, People, and Tags views (I recommend disabling this for larger libraries for significantly better performance).",
                                        content: AnyView(Toggle("", isOn: $enableThumbnailAnimation).labelsHidden()),
                                        isOn: enableThumbnailAnimation
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
                                    
                                    SettingsRow(
                                        icon: "rectangle.split.3x1",
                                        title: "Navigation Style",
                                        subtitle: "Choose between a classic tab bar or the adaptive sidebar layout",
                                        content: AnyView(
                                            Picker("Navigation Style", selection: Binding(
                                                get: { NavigationStyle(rawValue: navigationStyle) ?? .tabs },
                                                set: { navigationStyle = $0.rawValue }
                                            )) {
                                                ForEach(NavigationStyle.allCases, id: \.self) { style in
                                                    Text(style.displayName).tag(style)
                                                }
                                            }
                                                .pickerStyle(.menu)
                                                .frame(width: 300, alignment: .trailing)
                                        )
                                    )
                                }
                            )
                        }
                        
                        // TopShelf Settings Section
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
                                            Text("Off").tag("off")
                                            Text("Compact").tag("sectioned")
                                            Text("Fullscreen").tag("carousel")
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
                                            Picker("Image Selection", selection: $topShelfImageSelection) {
                                                Text("Recent Photos").tag("recent")
                                                Text("Random Photos").tag("random")
                                            }
                                                .pickerStyle(.menu)
                                                .frame(width: 500, alignment: .trailing)
                                        )
                                    )
                                }
                            })
                        }
                        
                        // Sorting Settings Section
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
                        
                        // Slideshow Settings Section
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
                        
                        // Statistics Section
                        SettingsSection(title: "Statistics") {
                            AnyView(
                                Button(action: {
                                    showingStats = true
                                }) {
                                    HStack {
                                        Image(systemName: "chart.bar.xaxis")
                                            .foregroundColor(.blue)
                                            .font(.title3)
                                            .frame(width: 24)
                                            .padding()
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("View Library Statistics")
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                            Text("See detailed stats about your photos, videos, people, and locations")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                    .padding(16)
                                    .background(Color.gray.opacity(0.05))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(CardButtonStyle())
                            )
                        }
                        
                        // Cache Section (Debug only)
                        
#if DEBUG
                        CacheSection(
                            thumbnailCache: thumbnailCache,
                            showingClearCacheAlert: $showingClearCacheAlert
                        )
#endif
                    }
                    .padding()
                }
            }
            .fullScreenCover(isPresented: $showingSignIn) {
                SignInView(authService: authService, userManager: userManager, mode: .addUser, onUserAdded: { userManager.loadUsers() })
            }
            .fullScreenCover(isPresented: $showingStats) {
                StatsView(statsService: createStatsService())
            }
            .alert("Clear Cache", isPresented: $showingClearCacheAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    thumbnailCache.clearAllCaches()
                }
            } message: {
                Text("This will remove all cached thumbnails from both memory and disk. Images will be re-downloaded when needed.")
            }
            .alert("Delete User", isPresented: $showingDeleteUserAlert) {
                Button("Cancel", role: .cancel) {
                    userToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let user = userToDelete {
                        removeUser(user)
                    }
                    userToDelete = nil
                }
            } message: {
                if let user = userToDelete {
                    let isCurrentUser = userManager.currentUser?.id == user.id
                    let isLastUser = userManager.savedUsers.count == 1
                    
                    if isCurrentUser && isLastUser {
                        Text("Are you sure you want to delete this user? This will sign you out and you'll need to sign in again to access your photos.")
                    } else if isCurrentUser {
                        Text("Are you sure you want to delete the current user? You will be switched to another saved user.")
                    } else {
                        Text("Are you sure you want to delete this user account?")
                    }
                } else {
                    Text("Are you sure you want to delete this user?")
                }
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
            .onAppear {
                userManager.loadUsers()
                thumbnailCache.refreshCacheStatistics()
            }
        }
    }
    
    
    private func switchToUser(_ user: SavedUser) {
        Task {
            do {
                try await authService.switchUser(user)
                
                await MainActor.run {
                    // Refresh the app by posting a notification
                    NotificationCenter.default.post(name: NSNotification.Name(NotificationNames.refreshAllTabs), object: nil)
                }
                
            } catch {
                debugLog("SettingsView: Failed to switch user: \(error)")
                // Handle error - could show alert to user
            }
        }
    }
    
    
    private func removeUser(_ user: SavedUser) {
        Task {
            do {
                let wasCurrentUser = userManager.currentUser?.id == user.id
                
                try await userManager.removeUser(user)
                
                // If we removed the current user, update the authentication service
                if wasCurrentUser {
                    if userManager.hasCurrentUser {
                        // Switch to the new current user
                        debugLog("SettingsView: Switching to next available user after removal")
                        authService.updateCredentialsFromCurrentUser()
                        
                        await MainActor.run {
                            authService.isAuthenticated = true
                        }
                        
                        // Fetch the new current user info
                        try await authService.fetchUserInfo()
                        
                        // Refresh the app UI
                        NotificationCenter.default.post(name: NSNotification.Name(NotificationNames.refreshAllTabs), object: nil)
                    } else {
                        // No users left, sign out completely
                        debugLog("SettingsView: No users left, signing out completely")
                        await MainActor.run {
                            authService.isAuthenticated = false
                            authService.currentUser = nil
                        }
                        authService.clearCredentials()
                    }
                }
            } catch {
                debugLog("SettingsView: Failed to remove user: \(error)")
                // Handle error - could show alert to user
            }
        }
    }
    
    
    
    
    private func refreshServerConnection() {
        Task {
            do {
                // Refresh user info to verify connection
                try await authService.fetchUserInfo()
                debugLog("✅ Server connection refreshed successfully")
                
                // Post notification to refresh all tabs
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name(NotificationNames.refreshAllTabs), object: nil)
                }
            } catch {
                debugLog("❌ Failed to refresh server connection: \(error)")
                // You could add an alert here to show the error to the user
            }
        }
    }
    
    private func createStatsService() -> StatsService {
        let networkService = NetworkService(userManager: userManager)
        let exploreService = ExploreService(networkService: networkService)
        let peopleService = PeopleService(networkService: networkService)
        return StatsService(exploreService: exploreService, peopleService: peopleService, networkService: networkService)
    }
}


#Preview {
    let userManager = UserManager()
    
    // Create fake users for preview
    let apiKeyUser = SavedUser(
        id: "1",
        email: "admin@example.com",
        name: "Admin User",
        serverURL: "https://demo.immich.app",
        authType: .apiKey
    )
    
    let passwordUser = SavedUser(
        id: "2",
        email: "john.doe@company.com",
        name: "John Doe",
        serverURL: "https://photos.myserver.com",
        authType: .jwt
    )
    
    let anotherApiKeyUser = SavedUser(
        id: "3",
        email: "service@automation.net",
        name: "Service Account",
        serverURL: "https://immich.local:2283",
        authType: .apiKey
    )
    
    // Set fake data after initialization
    DispatchQueue.main.async {
        userManager.savedUsers = [apiKeyUser, passwordUser, anotherApiKeyUser]
        userManager.currentUser = passwordUser
    }
    
    let networkService = NetworkService(userManager: userManager)
    let authService = AuthenticationService(networkService: networkService, userManager: userManager)
    
    return SettingsView(authService: authService, userManager: userManager)
}

