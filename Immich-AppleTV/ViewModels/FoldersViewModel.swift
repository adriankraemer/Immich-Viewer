//
//  FoldersViewModel.swift
//  Immich-AppleTV
//
//  ViewModel for Folders feature following MVVM pattern
//  Handles folders loading and state management
//

import Foundation
import SwiftUI

@MainActor
class FoldersViewModel: ObservableObject {
    // MARK: - Published Properties (View State)
    @Published var folders: [ImmichFolder] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedFolder: ImmichFolder?
    
    // MARK: - Dependencies
    private let folderService: FolderService
    
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
            } catch {
                debugLog("FoldersViewModel: Error fetching folders: \(error)")
                self.errorMessage = "Failed to load folders: \(error.localizedDescription)"
                self.isLoading = false
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
        loadFolders()
    }
    
    /// Loads folders if not already loaded
    func loadFoldersIfNeeded() {
        if folders.isEmpty && !isLoading {
            loadFolders()
        }
    }
}

