//
//  ContinentDetailView.swift
//  Immich-AppleTV
//
//  View showing countries within a continent
//

import SwiftUI

struct ContinentDetailView: View {
    @StateObject private var viewModel: ContinentViewModel
    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var exploreService: ExploreService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCountry: Country?
    
    init(continent: Continent, assetService: AssetService, authService: AuthenticationService, exploreService: ExploreService) {
        _viewModel = StateObject(wrappedValue: ContinentViewModel(continent: continent, assetService: assetService))
        self.assetService = assetService
        self.authService = authService
        self.exploreService = exploreService
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                SharedGradientBackground()
                
                SharedGridView(
                    items: viewModel.countries,
                    config: GridConfig.peopleStyle,
                    thumbnailProvider: CountryThumbnailProvider(assetService: assetService),
                    isLoading: viewModel.isLoading,
                    errorMessage: viewModel.errorMessage,
                    onItemSelected: { country in
                        selectedCountry = country
                    },
                    onRetry: {
                        Task {
                            // Countries are already loaded from continent, no retry needed
                        }
                    }
                )
            }
            .navigationTitle(viewModel.continentName)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .fullScreenCover(item: $selectedCountry) { country in
            CountryDetailView(country: country, assetService: assetService, authService: authService, exploreService: exploreService)
        }
    }
}

