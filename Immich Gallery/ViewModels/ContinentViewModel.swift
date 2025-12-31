//
//  ContinentViewModel.swift
//  Immich Gallery
//
//  ViewModel for Continent detail view following MVVM pattern
//

import Foundation
import SwiftUI

@MainActor
class ContinentViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var countries: [Country] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let continent: Continent
    private let assetService: AssetService
    
    // MARK: - Initialization
    init(continent: Continent, assetService: AssetService) {
        self.continent = continent
        self.assetService = assetService
        self.countries = continent.countries
    }
    
    // MARK: - Computed Properties
    var continentName: String {
        continent.name
    }
    
    var totalCountries: Int {
        countries.count
    }
    
    var totalPhotos: Int {
        countries.reduce(0) { $0 + ($1.itemCount ?? 0) }
    }
}

