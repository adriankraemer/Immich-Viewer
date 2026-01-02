//
//  StatsViewModel.swift
//  Immich-AppleTV
//
//  ViewModel for Stats feature following MVVM pattern
//  Handles statistics loading, caching, and state management
//

import Foundation
import SwiftUI
import Combine

@MainActor
class StatsViewModel: ObservableObject {
    // MARK: - Published Properties (View State)
    @Published var statsData: StatsData?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var lastUpdated: Date?
    
    // MARK: - Dependencies
    private let statsService: StatsService
    
    // MARK: - Internal State
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var hasStats: Bool {
        statsData != nil
    }
    
    var hasError: Bool {
        error != nil
    }
    
    var formattedLastUpdated: String? {
        guard let lastUpdated = lastUpdated else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastUpdated, relativeTo: Date())
    }
    
    // MARK: - Initialization
    
    init(statsService: StatsService) {
        self.statsService = statsService
        setupNotificationObserver()
    }
    
    // MARK: - Public Methods
    
    /// Loads stats if not already loaded or cached
    func loadStatsIfNeeded() {
        guard statsData == nil && !isLoading else { return }
        
        debugLog("StatsViewModel: loadStatsIfNeeded called")
        
        // Check if we have cached data first
        if let cachedStats = StatsCache.shared.getCachedStats() {
            debugLog("StatsViewModel: Using cached stats")
            statsData = cachedStats
            lastUpdated = cachedStats.cachedAt
            return
        }
        
        // Load fresh data
        refreshStats()
    }
    
    /// Forces a refresh of statistics
    func refreshStats() {
        debugLog("StatsViewModel: refreshStats called")
        
        isLoading = true
        error = nil
        
        Task {
            do {
                let stats = try await statsService.getStats(forceRefresh: true)
                debugLog("StatsViewModel: Successfully loaded stats")
                self.statsData = stats
                self.lastUpdated = stats.cachedAt
                self.isLoading = false
            } catch {
                debugLog("StatsViewModel: Error loading stats: \(error)")
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    /// Clears cached data and refreshes
    func clearAndRefresh() {
        debugLog("StatsViewModel: clearAndRefresh called")
        StatsCache.shared.clearCache()
        statsData = nil
        lastUpdated = nil
        error = nil
        refreshStats()
    }
    
    /// Retries loading stats
    func retry() {
        refreshStats()
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationObserver() {
        NotificationCenter.default.publisher(for: NSNotification.Name(NotificationNames.refreshAllTabs))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.clearAndRefresh()
            }
            .store(in: &cancellables)
    }
}

