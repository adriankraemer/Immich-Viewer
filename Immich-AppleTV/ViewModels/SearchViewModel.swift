//
//  SearchViewModel.swift
//  Immich-AppleTV
//
//  ViewModel for Search feature following MVVM pattern
//  Handles search functionality and result state management
//

import Foundation
import SwiftUI
import Combine

@MainActor
class SearchViewModel: ObservableObject {
    // MARK: - Published Properties (View State)
    @Published var searchText = ""
    @Published var assets: [ImmichAsset] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedAsset: ImmichAsset?
    @Published var currentAssetIndex: Int = 0
    
    // MARK: - Dependencies
    private let searchService: SearchService
    private let assetService: AssetService
    private let authService: AuthenticationService
    
    // MARK: - Internal State
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var hasResults: Bool {
        !assets.isEmpty
    }
    
    var showEmptyState: Bool {
        !searchText.isEmpty && assets.isEmpty && !isLoading
    }
    
    var showInitialState: Bool {
        searchText.isEmpty && assets.isEmpty && !isLoading
    }
    
    // MARK: - Initialization
    
    init(
        searchService: SearchService,
        assetService: AssetService,
        authService: AuthenticationService
    ) {
        self.searchService = searchService
        self.assetService = assetService
        self.authService = authService
        
        setupSearchTextObserver()
    }
    
    // MARK: - Public Methods
    
    /// Performs a search with the current search text
    func performSearch() {
        let trimmedText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return
        }
        
        debugLog("SearchViewModel: Performing search for: '\(trimmedText)'")
        
        // Cancel any existing search task
        searchTask?.cancel()
        
        searchTask = Task {
            isLoading = true
            errorMessage = nil
            assets = []
            
            do {
                let result = try await searchService.searchAssets(query: trimmedText)
                
                if Task.isCancelled { return }
                
                debugLog("SearchViewModel: Search completed, found \(result.assets.count) assets")
                assets = result.assets
                isLoading = false
            } catch {
                if Task.isCancelled { return }
                
                debugLog("SearchViewModel: Search failed with error: \(error)")
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    /// Selects an asset and updates the current index
    func selectAsset(_ asset: ImmichAsset) {
        debugLog("SearchViewModel: Asset selected: \(asset.id)")
        selectedAsset = asset
        if let index = assets.firstIndex(of: asset) {
            currentAssetIndex = index
            debugLog("SearchViewModel: Set currentAssetIndex to \(index)")
        }
    }
    
    /// Retries the last search
    func retry() {
        performSearch()
    }
    
    /// Clears search results and resets state
    func clearSearch() {
        searchText = ""
        assets = []
        errorMessage = nil
        searchTask?.cancel()
    }
    
    // MARK: - Private Methods
    
    private func setupSearchTextObserver() {
        // Debounce search text changes to avoid too many API calls while typing
        $searchText
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] newText in
                guard let self = self else { return }
                if !newText.isEmpty {
                    self.performSearch()
                }
            }
            .store(in: &cancellables)
    }
}

