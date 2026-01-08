import Foundation
import SwiftUI

/// View mode for folder display
enum FolderViewMode: String, CaseIterable {
    case grid = "grid"
    case tree = "tree"
    case timeline = "timeline"
    
    var displayName: String {
        switch self {
        case .grid: return "Grid"
        case .tree: return "Tree"
        case .timeline: return "Timeline"
        }
    }
}

@MainActor
class FoldersViewModel: ObservableObject {
    // MARK: - Published Properties (View State)
    @Published var folders: [ImmichFolder] = []
    @Published var folderTree: [ImmichFolder] = []           // For tree view
    @Published var timelineGroups: [FolderTimelineGroup] = [] // For timeline view
    @Published var isLoading = false
    @Published var isLoadingTimeline = false                  // Separate loading state for timeline dates
    @Published var errorMessage: String?
    @Published var selectedFolder: ImmichFolder?
    
    // MARK: - View Mode
    var viewMode: FolderViewMode {
        let stored = UserDefaults.standard.folderViewMode
        return FolderViewMode(rawValue: stored) ?? .grid
    }
    
    // MARK: - Dependencies
    private let folderService: FolderService
    
    // MARK: - Private State
    private var hasLoadedTree = false
    private var hasLoadedTimeline = false
    
    // MARK: - Initialization
    
    init(folderService: FolderService) {
        self.folderService = folderService
    }
    
    // MARK: - Public Methods
    
    /// Loads all folders from the service
    func loadFolders() {
        debugLog("FoldersViewModel: loadFolders called")
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedFolders = try await folderService.fetchUniquePaths()
                debugLog("FoldersViewModel: Successfully fetched \(fetchedFolders.count) folders")
                
                // Remove duplicates and sort
                let uniqueFolders = Array(Set(fetchedFolders))
                self.folders = uniqueFolders.sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }
                self.isLoading = false
                
                // Build tree structure
                self.buildTree()
                
                // Reset timeline state so it reloads with new data
                self.hasLoadedTimeline = false
                
            } catch {
                debugLog("FoldersViewModel: Error fetching folders: \(error)")
                self.errorMessage = "Failed to load folders: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    /// Builds the folder tree from flat folders
    func buildTree() {
        guard !folders.isEmpty else { return }
        debugLog("FoldersViewModel: Building folder tree from \(folders.count) folders")
        folderTree = folderService.buildFolderTree(from: folders)
        hasLoadedTree = true
        debugLog("FoldersViewModel: Built tree with \(folderTree.count) root folders")
    }
    
    /// Loads timeline data (fetches dates for folders)
    func loadTimeline() {
        guard !folders.isEmpty else { return }
        guard !isLoadingTimeline else { return }
        
        debugLog("FoldersViewModel: Loading timeline data for \(folders.count) folders")
        isLoadingTimeline = true
        
        Task {
            // Fetch dates for all folders
            let foldersWithDates = await folderService.fetchFoldersWithDates(folders)
            
            // Group folders by date
            self.timelineGroups = folderService.groupFoldersForTimeline(foldersWithDates)
            self.hasLoadedTimeline = true
            self.isLoadingTimeline = false
            
            debugLog("FoldersViewModel: Created \(timelineGroups.count) timeline groups")
        }
    }
    
    /// Ensures data is loaded for the current view mode
    func ensureDataForViewMode() {
        switch viewMode {
        case .grid:
            // Grid uses folders directly, no additional processing needed
            break
        case .tree:
            if !hasLoadedTree && !folders.isEmpty {
                buildTree()
            }
        case .timeline:
            if !hasLoadedTimeline && !folders.isEmpty {
                loadTimeline()
            }
        }
    }
    
    /// Selects a folder
    func selectFolder(_ folder: ImmichFolder) {
        debugLog("FoldersViewModel: Folder selected: \(folder.path)")
        selectedFolder = folder
    }
    
    /// Clears the selected folder
    func clearSelection() {
        selectedFolder = nil
    }
    
    /// Retries loading folders
    func retry() {
        hasLoadedTree = false
        hasLoadedTimeline = false
        loadFolders()
    }
    
    /// Loads folders if not already loaded
    func loadFoldersIfNeeded() {
        if folders.isEmpty && !isLoading {
            loadFolders()
        }
    }
    
    /// Refreshes data for the current view mode
    func refresh() {
        switch viewMode {
        case .grid:
            loadFolders()
        case .tree:
            hasLoadedTree = false
            loadFolders()
        case .timeline:
            hasLoadedTimeline = false
            folderService.clearCache()
            loadFolders()
        }
    }
}

