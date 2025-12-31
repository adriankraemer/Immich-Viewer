//
//  CountryViewModel.swift
//  Immich Gallery
//
//  ViewModel for Country detail view following MVVM pattern
//

import Foundation
import SwiftUI

@MainActor
class CountryViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var cities: [City] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let country: Country
    private let assetService: AssetService
    
    // MARK: - Initialization
    init(country: Country, assetService: AssetService) {
        self.country = country
        self.assetService = assetService
        self.cities = country.cities
    }
    
    // MARK: - Computed Properties
    var countryName: String {
        country.name
    }
    
    var continentName: String {
        country.continent
    }
    
    var totalCities: Int {
        cities.count
    }
}

