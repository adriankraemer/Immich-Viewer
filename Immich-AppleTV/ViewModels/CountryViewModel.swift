//
//  CountryViewModel.swift
//  Immich-AppleTV
//
//  ViewModel for Country detail view following MVVM pattern
//

import Foundation
import SwiftUI

@MainActor
class CountryViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var assets: [ImmichAsset] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let country: Country
    private let assetService: AssetService
    private let exploreService: ExploreService
    
    // MARK: - Initialization
    init(country: Country, assetService: AssetService, exploreService: ExploreService) {
        self.country = country
        self.assetService = assetService
        self.exploreService = exploreService
    }
    
    // MARK: - Computed Properties
    var countryName: String {
        country.name
    }
    
    var continentName: String {
        country.continent
    }
    
    var totalPhotos: Int {
        country.assetCount
    }
    
    func createAssetProvider() -> AssetProvider {
        return OnDemandCountryAssetProvider(countryName: country.name, exploreService: exploreService)
    }
}

