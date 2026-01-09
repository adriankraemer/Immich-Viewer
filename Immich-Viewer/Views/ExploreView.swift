import SwiftUI

// MARK: - Cinematic Theme Constants for Explore
private enum ExploreTheme {
    static let accent = Color(red: 245/255, green: 166/255, blue: 35/255)
    static let surface = Color(red: 30/255, green: 30/255, blue: 32/255)
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 142/255, green: 142/255, blue: 147/255)
    static let textTertiary = Color(red: 99/255, green: 99/255, blue: 102/255)
}

struct ExploreView: View {
    @ObservedObject var exploreService: ExploreService
    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    
    @StateObject private var viewModel: ExploreViewModel
    @State private var selectedContinent: Continent?
    @State private var exploreLoadingRotation: Double = 0
    
    init(exploreService: ExploreService, assetService: AssetService, authService: AuthenticationService) {
        self.exploreService = exploreService
        self.assetService = assetService
        self.authService = authService
        _viewModel = StateObject(wrappedValue: ExploreViewModel(exploreService: exploreService, assetService: assetService))
    }
    
    var body: some View {
        ZStack {
            SharedGradientBackground()
            
            if viewModel.isLoading {
                // Cinematic loading state
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .stroke(ExploreTheme.surface, lineWidth: 4)
                            .frame(width: 70, height: 70)
                        
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(
                                AngularGradient(
                                    colors: [ExploreTheme.accent, ExploreTheme.accent.opacity(0.3)],
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 70, height: 70)
                            .rotationEffect(.degrees(exploreLoadingRotation))
                    }
                    
                    Text(String(localized: "Loading explore data..."))
                        .font(.headline)
                        .foregroundColor(ExploreTheme.textSecondary)
                }
                .onAppear {
                    withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                        exploreLoadingRotation = 360
                    }
                }
            } else if let errorMessage = viewModel.errorMessage {
                // Cinematic error state
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(ExploreTheme.surface)
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.orange, Color.red],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    
                    VStack(spacing: 12) {
                        Text(String(localized: "Something went wrong"))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(ExploreTheme.textPrimary)
                        
                        Text(errorMessage)
                            .font(.body)
                            .foregroundColor(ExploreTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 500)
                    }
                    
                    Button(action: {
                        Task { await viewModel.refresh() }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.clockwise")
                            Text(String(localized: "Try Again"))
                        }
                        .font(.headline)
                        .foregroundColor(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(ExploreTheme.accent)
                        .cornerRadius(12)
                    }
                    .buttonStyle(CardButtonStyle())
                }
            } else if viewModel.continents.isEmpty {
                // Cinematic empty state
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(ExploreTheme.surface)
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "globe")
                            .font(.system(size: 50))
                            .foregroundColor(ExploreTheme.textTertiary)
                    }
                    
                    VStack(spacing: 12) {
                        Text(String(localized: "No Places Found"))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(ExploreTheme.textPrimary)
                        
                        Text(String(localized: "Photos with location data will appear here"))
                            .font(.body)
                            .foregroundColor(ExploreTheme.textSecondary)
                    }
                }
            } else {
                SharedGridView(
                    items: viewModel.continents,
                    config: GridConfig.peopleStyle,
                    thumbnailProvider: ContinentThumbnailProvider(assetService: assetService),
                    isLoading: viewModel.isLoading,
                    errorMessage: viewModel.errorMessage,
                    onItemSelected: { continent in
                        selectedContinent = continent
                    },
                    onRetry: {
                        Task {
                            await viewModel.refresh()
                        }
                    }
                )
            }
        }
        .fullScreenCover(item: $selectedContinent) { continent in
            ContinentDetailView(continent: continent, assetService: assetService, authService: authService, exploreService: exploreService)
        }
        .onAppear {
            if viewModel.continents.isEmpty {
                Task {
                    await viewModel.loadExploreData()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name(NotificationNames.refreshAllTabs))) { _ in
            // Reset state and reload data when user switches
            Task {
                await viewModel.refresh()
            }
        }
    }
}
