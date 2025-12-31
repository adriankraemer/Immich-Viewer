//
//  CountryDetailView.swift
//  Immich Gallery
//
//  View showing cities within a country
//

import SwiftUI

struct CountryDetailView: View {
    @StateObject private var viewModel: CountryViewModel
    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCity: City?
    
    init(country: Country, assetService: AssetService, authService: AuthenticationService) {
        _viewModel = StateObject(wrappedValue: CountryViewModel(country: country, assetService: assetService))
        self.assetService = assetService
        self.authService = authService
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                SharedGradientBackground()
                
                SharedGridView(
                    items: viewModel.cities,
                    config: GridConfig.peopleStyle,
                    thumbnailProvider: CityThumbnailProvider(assetService: assetService),
                    isLoading: viewModel.isLoading,
                    errorMessage: viewModel.errorMessage,
                    onItemSelected: { city in
                        selectedCity = city as? City
                    },
                    onRetry: {
                        Task {
                            // Cities are already loaded from country, no retry needed
                        }
                    }
                )
            }
            .navigationTitle(viewModel.countryName)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .fullScreenCover(item: $selectedCity) { city in
            ExploreDetailView(city: city.name, assetService: assetService, authService: authService)
        }
    }
}

