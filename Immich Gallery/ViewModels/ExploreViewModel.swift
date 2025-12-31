//
//  ExploreViewModel.swift
//  Immich Gallery
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
            let assets = try await exploreService.fetchExploreData()
            continents = ContinentMapper.organizeAssets(assets: assets)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    func refresh() async {
        await loadExploreData()
    }
}

