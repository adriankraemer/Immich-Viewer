import SwiftUI

// MARK: - Settings Category Enum

enum SettingsCategory: String, CaseIterable, Identifiable {
    case account = "Account"
    case display = "Display"
    case slideshow = "Slideshow"
    case topShelf = "Top Shelf"
    case statistics = "Statistics"
    case cache = "Cache"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .account: return "person.circle"
        case .display: return "display"
        case .slideshow: return "play.rectangle"
        case .topShelf: return "tv"
        case .statistics: return "chart.bar"
        case .cache: return "internaldrive"
        }
    }
    
    var description: String {
        switch self {
        case .account: return "Users and server"
        case .display: return "Interface and navigation"
        case .slideshow: return "Slideshow settings"
        case .topShelf: return "Apple TV Top Shelf"
        case .statistics: return "Library statistics"
        case .cache: return "Cache management"
        }
    }
}

// MARK: - Sidebar Button Style

struct SidebarButtonStyle: ButtonStyle {
    let isSelected: Bool
    @Environment(\.isFocused) var isFocused
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : (isFocused ? 1.02 : 1.0))
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isFocused)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
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
        HStack(spacing: 20) {
            // Icon with background
            ZStack {
                Circle()
                    .fill(isOn ? Color.green.opacity(0.2) : Color.blue.opacity(0.15))
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .foregroundColor(isOn ? .green : .blue)
                    .font(.system(size: 28, weight: .medium))
            }
            .frame(width: 60, height: 60)
            
            // Text content
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Control content
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    isOn ? 
                    LinearGradient(
                        colors: [Color.green.opacity(0.1), Color.green.opacity(0.05)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(
                        colors: [Color.gray.opacity(0.08), Color.gray.opacity(0.04)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isOn ? Color.green.opacity(0.3) : Color.white.opacity(0.1),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Main Settings View

struct SettingsView: View {
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var userManager: UserManager
    @State private var selectedCategory: SettingsCategory = .account
    @FocusState private var focusedSidebarItem: SettingsCategory?
    
    
    var body: some View {
        NavigationView {
            ZStack {
                SharedGradientBackground()
                    .ignoresSafeArea()
                
                HStack(spacing: 0) {
                    // Sidebar
                    sidebarView
                        .frame(width: 450)
                    
                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1)
                    
                    // Content Area
                    contentView
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebarView: some View {
        VStack(spacing: 0) {
            // Sidebar Header
            VStack(alignment: .leading, spacing: 12) {
                Text("Settings")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.top, 40)
                
                Text("Choose a category")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Sidebar Items
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(SettingsCategory.allCases) { category in
                        // Skip cache in non-debug builds
                        #if !DEBUG
                        if category == .cache {
                            EmptyView()
                        } else {
                            sidebarItem(category: category)
                        }
                        #else
                        sidebarItem(category: category)
                        #endif
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 20)
            }
        }
        .background(
            ZStack {
                Color.black.opacity(0.3)
                // Subtle gradient overlay
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        )
        .onAppear {
            // Set initial focus to the selected category
            focusedSidebarItem = selectedCategory
        }
    }
    
    private func sidebarItem(category: SettingsCategory) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedCategory = category
            }
        }) {
            HStack(spacing: 24) {
                // Icon with background circle
                ZStack {
                    Circle()
                        .fill((selectedCategory == category || focusedSidebarItem == category) ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor((selectedCategory == category || focusedSidebarItem == category) ? .white : .secondary)
                }
                .frame(width: 60, height: 60)
                
                // Text content
                VStack(alignment: .leading, spacing: 6) {
                    Text(category.rawValue)
                        .font(.system(size: 28, weight: (selectedCategory == category || focusedSidebarItem == category) ? .semibold : .regular))
                        .foregroundColor((selectedCategory == category || focusedSidebarItem == category) ? .white : .primary)
                    
                    Text(category.description)
                        .font(.system(size: 20))
                        .foregroundColor((selectedCategory == category || focusedSidebarItem == category) ? .white.opacity(0.8) : .secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Selection indicator
                if selectedCategory == category {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill((selectedCategory == category || focusedSidebarItem == category) ? 
                          LinearGradient(
                            colors: [Color.blue.opacity(0.4), Color.blue.opacity(0.2)],
                            startPoint: .leading,
                            endPoint: .trailing
                          ) : 
                          LinearGradient(
                            colors: [Color.clear, Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                          )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        (selectedCategory == category || focusedSidebarItem == category) ? 
                        LinearGradient(
                            colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.4)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ) : 
                        LinearGradient(
                            colors: [Color.clear, Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(
                color: (selectedCategory == category || focusedSidebarItem == category) ? Color.blue.opacity(0.3) : Color.clear,
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(SidebarButtonStyle(isSelected: selectedCategory == category || focusedSidebarItem == category))
        .focused($focusedSidebarItem, equals: category)
        .onMoveCommand { direction in
            handleSidebarNavigation(direction: direction, currentCategory: category)
        }
        .onChange(of: focusedSidebarItem) { oldValue, newValue in
            if let newValue = newValue, newValue == category {
                // When a sidebar item gets focus, select it
                if selectedCategory != category {
                    withAnimation {
                        selectedCategory = category
                    }
                }
            }
        }
    }
    
    private func handleSidebarNavigation(direction: MoveCommandDirection, currentCategory: SettingsCategory) {
        let categories = SettingsCategory.allCases.filter { category in
            #if !DEBUG
            return category != .cache
            #else
            return true
            #endif
        }
        
        guard let currentIndex = categories.firstIndex(of: currentCategory) else { return }
        
        switch direction {
        case .up:
            if currentIndex > 0 {
                withAnimation {
                    focusedSidebarItem = categories[currentIndex - 1]
                }
            }
        case .down:
            if currentIndex < categories.count - 1 {
                withAnimation {
                    focusedSidebarItem = categories[currentIndex + 1]
                }
            }
        case .left:
            // Already in sidebar, do nothing
            break
        case .right:
            // Move focus to content area
            focusedSidebarItem = nil
        @unknown default:
            break
        }
    }
    
    // MARK: - Content Area
    
    @ViewBuilder
    private var contentView: some View {
        ZStack {
            SharedGradientBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Content Header
                HStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(selectedCategory.rawValue)
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(selectedCategory.description)
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 40)
                .padding(.top, 40)
                .padding(.bottom, 30)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.2), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                // Content Body
                Group {
                    switch selectedCategory {
                    case .account:
                        AccountSettingsView(authService: authService, userManager: userManager)
                            .onMoveCommand { direction in
                                if direction == .left {
                                    // Move focus to sidebar
                                    focusedSidebarItem = selectedCategory
                                }
                            }
                    case .display:
                        DisplaySettingsView()
                            .onMoveCommand { direction in
                                if direction == .left {
                                    focusedSidebarItem = selectedCategory
                                }
                            }
                    case .slideshow:
                        SlideshowSettingsView()
                            .onMoveCommand { direction in
                                if direction == .left {
                                    focusedSidebarItem = selectedCategory
                                }
                            }
                    case .topShelf:
                        TopShelfSettingsView()
                            .onMoveCommand { direction in
                                if direction == .left {
                                    focusedSidebarItem = selectedCategory
                                }
                            }
                    case .statistics:
                        StatisticsSettingsView(userManager: userManager)
                            .onMoveCommand { direction in
                                if direction == .left {
                                    focusedSidebarItem = selectedCategory
                                }
                            }
                    case .cache:
                        #if DEBUG
                        CacheSettingsView(thumbnailCache: thumbnailCache)
                            .onMoveCommand { direction in
                                if direction == .left {
                                    focusedSidebarItem = selectedCategory
                                }
                            }
                        #else
                        EmptyView()
                        #endif
                    }
                }
            }
        }
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

