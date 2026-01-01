//
//  ExploreView.swift
//  Immich-AppleTV
//
//  Refactored to follow MVVM pattern with hierarchical location structure
//

import SwiftUI

struct ExploreView: View {
    @ObservedObject var exploreService: ExploreService
    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var userManager: UserManager
    
    @StateObject private var viewModel: ExploreViewModel
    @State private var selectedContinent: Continent?
    @State private var showingStats = false
    
    init(exploreService: ExploreService, assetService: AssetService, authService: AuthenticationService, userManager: UserManager) {
        self.exploreService = exploreService
        self.assetService = assetService
        self.authService = authService
        self.userManager = userManager
        _viewModel = StateObject(wrappedValue: ExploreViewModel(exploreService: exploreService, assetService: assetService))
    }
    
    var body: some View {
        ZStack {
            SharedGradientBackground()
            
            if viewModel.isLoading {
                ProgressView("Loading explore data...")
                    .foregroundColor(.white)
                    .scaleEffect(1.5)
            } else if let errorMessage = viewModel.errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    Text("Error")
                        .font(.title)
                        .foregroundColor(.white)
                    Text(errorMessage)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Retry") {
                        Task {
                            await viewModel.refresh()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if viewModel.continents.isEmpty {
                VStack {
                    Image(systemName: "globe")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No Places Found")
                        .font(.title)
                        .foregroundColor(.white)
                    Text("Photos with location data will appear here")
                        .foregroundColor(.gray)
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
        .fullScreenCover(isPresented: $showingStats) {
            StatsView(statsService: createStatsService())
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
    
    private func createStatsService() -> StatsService {
        let networkService = NetworkService(userManager: userManager)
        let exploreService = ExploreService(networkService: networkService)
        let peopleService = PeopleService(networkService: networkService)
        return StatsService(exploreService: exploreService, peopleService: peopleService, networkService: networkService)
    }
}
