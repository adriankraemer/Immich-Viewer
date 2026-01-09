import SwiftUI

// MARK: - Cinematic Theme Constants for Stats
private enum StatsTheme {
    static let accent = Color(red: 245/255, green: 166/255, blue: 35/255)
    static let surface = Color(red: 30/255, green: 30/255, blue: 32/255)
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 142/255, green: 142/255, blue: 147/255)
}

struct StatsView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel: StatsViewModel
    
    // MARK: - Initialization
    
    init(statsService: StatsService) {
        _viewModel = StateObject(wrappedValue: StatsViewModel(
            statsService: statsService
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                SharedGradientBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 30) {
                        // Header Section
                        headerSection
                        
                        // Stats Sections
                        if let stats = viewModel.statsData {
                            assetStatsSection(stats.assetData)
                            exploreStatsSection(stats.exploreData)
                            peopleStatsSection(stats.peopleData)
                        }
                        
                        // Loading or Error State
                        if viewModel.isLoading {
                            loadingSection
                        } else if viewModel.hasError {
                            errorSection
                        }
                    }
                    .padding()
                }
            }
            .onAppear {
                viewModel.loadStatsIfNeeded()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        HStack(spacing: 20) {
            // Icon with cinematic styling
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                StatsTheme.accent.opacity(0.2),
                                StatsTheme.accent.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(StatsTheme.accent)
                    .font(.system(size: 28, weight: .medium))
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "Library Statistics"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(StatsTheme.textPrimary)
                
                if let lastUpdated = viewModel.formattedLastUpdated {
                    Text(String(localized: "Last updated: \(lastUpdated)"))
                        .font(.subheadline)
                        .foregroundColor(StatsTheme.textSecondary)
                }
            }
            
            Spacer()
            
            Button(action: {
                viewModel.refreshStats()
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18, weight: .semibold))
                    Text(String(localized: "Refresh"))
                        .font(.headline)
                }
                .foregroundColor(StatsTheme.accent)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(StatsTheme.accent.opacity(0.15))
                        
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(StatsTheme.accent.opacity(0.3), lineWidth: 1)
                    }
                )
            }
            .buttonStyle(CardButtonStyle())
        }
        .padding(24)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(StatsTheme.surface.opacity(0.6))
                
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
                            colors: [StatsTheme.accent.opacity(0.2), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
    }
    
    private func assetStatsSection(_ assetData: AssetStatistics) -> some View {
        SettingsSection(title: "Library Content") {
            AnyView(VStack(spacing: 32) {
                HStack(spacing: 32) {
                    StatCard(
                        icon: "photo.stack.fill",
                        title: String(localized: "Total Assets"),
                        count: assetData.total,
                        color: .blue
                    )
                    
                    StatCard(
                        icon: "photo.fill",
                        title: String(localized: "Images"),
                        count: assetData.images,
                        color: .green
                    )
                    
                    StatCard(
                        icon: "video.fill",
                        title: String(localized: "Videos"),
                        count: assetData.videos,
                        color: .orange
                    )
                }
            })
        }
    }
    
    private func exploreStatsSection(_ exploreData: ExploreStatsData) -> some View {
        SettingsSection(title: "Places Visited") {
            AnyView(VStack(spacing: 32) {
                HStack(spacing: 32) {
                    StatCard(
                        icon: "globe",
                        title: String(localized: "Countries"),
                        count: exploreData.countries.count,
                        color: .green
                    )
                    
                    StatCard(
                        icon: "map",
                        title: String(localized: "States"),
                        count: exploreData.states.count,
                        color: .purple
                    )
                    
                    StatCard(
                        icon: "building.2",
                        title: String(localized: "Cities"),
                        count: exploreData.cities.count,
                        color: .orange
                    )
                }
            })
        }
    }
    
    private func peopleStatsSection(_ peopleData: PeopleStatsData) -> some View {
        SettingsSection(title: "People") {
            AnyView(VStack(spacing: 32) {
                VStack(spacing: 32) {
                    HStack(spacing: 32) {
                        StatCard(
                            icon: "person.3.fill",
                            title: String(localized: "Total People"),
                            count: peopleData.totalPeople,
                            color: .blue
                        )
                        StatCard(
                            icon: "person.fill.questionmark",
                            title: String(localized: "Unnamed"),
                            count: peopleData.unnamedPeople,
                            color: .gray
                        )
                        
                        StatCard(
                            icon: "person.fill.checkmark",
                            title: String(localized: "Named"),
                            count: peopleData.namedPeople,
                            color: .green
                        )
                        StatCard(
                            icon: "heart.fill",
                            title: String(localized: "Favorites"),
                            count: peopleData.favoritePeople,
                            color: .red
                        )
                    }
                }
            })
        }
    }
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text(String(localized: "Loading statistics..."))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: 100)
    }
    
    private var errorSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundColor(.red)
            
            Text(String(localized: "Failed to load statistics"))
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(String(localized: "Please check your connection and try again"))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                viewModel.retry()
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                        .foregroundColor(.red)
                    Text(String(localized: "Retry"))
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }
            .buttonStyle(CardButtonStyle())
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Cinematic Stat Card

struct StatCard: View {
    let icon: String
    let title: String
    let count: Int
    let color: Color
    
    private let surface = Color(red: 30/255, green: 30/255, blue: 32/255)
    private let textPrimary = Color.white
    private let textSecondary = Color(red: 142/255, green: 142/255, blue: 147/255)
    
    var body: some View {
        Button(action: {
            // Do nothing
        }) {
            VStack(spacing: 16) {
                // Icon with gradient background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.25), color.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(color)
                }
                
                VStack(spacing: 6) {
                    Text("\(count)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(textPrimary)
                    
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(surface.opacity(0.6))
                    
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
                                colors: [color.opacity(0.3), Color.white.opacity(0.05)],
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

// MARK: - Embedded Stats View (for Settings)

struct EmbeddedStatsView: View {
    @StateObject private var viewModel: StatsViewModel
    
    init(statsService: StatsService) {
        _viewModel = StateObject(wrappedValue: StatsViewModel(
            statsService: statsService
        ))
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Stats Sections
            if let stats = viewModel.statsData {
                embeddedAssetStatsSection(stats.assetData)
                embeddedExploreStatsSection(stats.exploreData)
                embeddedPeopleStatsSection(stats.peopleData)
                
                // Last updated info
                if let lastUpdated = viewModel.formattedLastUpdated {
                    HStack {
                        Text(LocalizedStringResource("Last updated: \(lastUpdated)"))
                            .font(.caption)
                            .foregroundColor(StatsTheme.textSecondary)
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.refreshStats()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(LocalizedStringResource("Refresh"))
                                    .font(.subheadline)
                            }
                            .foregroundColor(StatsTheme.accent)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(StatsTheme.accent.opacity(0.15))
                            )
                        }
                        .buttonStyle(CardButtonStyle())
                    }
                    .padding(.top, 8)
                }
            }
            
            // Loading State
            if viewModel.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text(LocalizedStringResource("Loading statistics..."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            }
            
            // Error State
            if viewModel.hasError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundColor(.red)
                    
                    Text(LocalizedStringResource("Failed to load statistics"))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Button(action: {
                        viewModel.retry()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .semibold))
                            Text(LocalizedStringResource("Retry"))
                                .font(.subheadline)
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.red.opacity(0.15))
                        )
                    }
                    .buttonStyle(CardButtonStyle())
                }
                .padding()
            }
        }
        .onAppear {
            viewModel.loadStatsIfNeeded()
        }
    }
    
    private func embeddedAssetStatsSection(_ assetData: AssetStatistics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringResource("Library Content"))
                .font(.headline)
                .foregroundColor(StatsTheme.textSecondary)
            
            HStack(spacing: 20) {
                EmbeddedStatCard(
                    icon: "photo.stack.fill",
                    title: "Total Assets",
                    count: assetData.total,
                    color: .blue
                )
                
                EmbeddedStatCard(
                    icon: "photo.fill",
                    title: "Images",
                    count: assetData.images,
                    color: .green
                )
                
                EmbeddedStatCard(
                    icon: "video.fill",
                    title: "Videos",
                    count: assetData.videos,
                    color: .orange
                )
            }
        }
    }
    
    private func embeddedExploreStatsSection(_ exploreData: ExploreStatsData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringResource("Places Visited"))
                .font(.headline)
                .foregroundColor(StatsTheme.textSecondary)
            
            HStack(spacing: 20) {
                EmbeddedStatCard(
                    icon: "globe",
                    title: "Countries",
                    count: exploreData.countries.count,
                    color: .green
                )
                
                EmbeddedStatCard(
                    icon: "map",
                    title: "States",
                    count: exploreData.states.count,
                    color: .purple
                )
                
                EmbeddedStatCard(
                    icon: "building.2",
                    title: "Cities",
                    count: exploreData.cities.count,
                    color: .orange
                )
            }
        }
    }
    
    private func embeddedPeopleStatsSection(_ peopleData: PeopleStatsData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringResource("People"))
                .font(.headline)
                .foregroundColor(StatsTheme.textSecondary)
            
            HStack(spacing: 20) {
                EmbeddedStatCard(
                    icon: "person.3.fill",
                    title: "Total",
                    count: peopleData.totalPeople,
                    color: .blue
                )
                
                EmbeddedStatCard(
                    icon: "person.fill.checkmark",
                    title: "Named",
                    count: peopleData.namedPeople,
                    color: .green
                )
                
                EmbeddedStatCard(
                    icon: "person.fill.questionmark",
                    title: "Unnamed",
                    count: peopleData.unnamedPeople,
                    color: .gray
                )
                
                EmbeddedStatCard(
                    icon: "heart.fill",
                    title: "Favorites",
                    count: peopleData.favoritePeople,
                    color: .red
                )
            }
        }
    }
}

// MARK: - Embedded Stat Card (Smaller for Settings)

struct EmbeddedStatCard: View {
    let icon: String
    let title: LocalizedStringKey
    let count: Int
    let color: Color
    
    private let surface = Color(red: 30/255, green: 30/255, blue: 32/255)
    private let textPrimary = Color.white
    private let textSecondary = Color(red: 142/255, green: 142/255, blue: 147/255)
    
    var body: some View {
        Button(action: {}) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.25), color.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(color)
                }
                
                VStack(spacing: 4) {
                    Text("\(count)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(textPrimary)
                    
                    Text(title)
                        .font(.caption)
                        .foregroundColor(textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(surface.opacity(0.6))
                    
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            LinearGradient(
                                colors: [color.opacity(0.3), Color.white.opacity(0.05)],
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

// MARK: - Preview

#Preview {
    let userManager = UserManager()
    let networkService = NetworkService(userManager: userManager)
    let exploreService = ExploreService(networkService: networkService)
    let peopleService = PeopleService(networkService: networkService)
    let statsService = StatsService(exploreService: exploreService, peopleService: peopleService, networkService: networkService)
    
    StatsView(statsService: statsService)
}
