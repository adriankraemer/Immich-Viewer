//
//  ExploreViewModel.swift
//  Immich-AppleTV
//
//  ViewModel for Explore feature following MVVM pattern
//

import Foundation
import SwiftUI
import Combine

@MainActor
class ExploreViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var continents: [Continent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let exploreService: ExploreService
    private let assetService: AssetService
    
    // MARK: - Initialization
    init(exploreService: ExploreService, assetService: AssetService) {
        self.exploreService = exploreService
        self.assetService = assetService
    }
    
    // MARK: - Public Methods
    func loadExploreData() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch lightweight location summaries (countries + counts only)
            let summaries = try await exploreService.fetchLocationSummaries()
            continents = ContinentMapper.organizeLocationSummaries(summaries)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    func refresh() async {
        // Clear existing data to show loading state
        continents = []
        await loadExploreData()
    }
}

