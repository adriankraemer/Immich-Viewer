//
//  TagsGridViewModel.swift
//  Immich-AppleTV
//
//  ViewModel for TagsGrid feature following MVVM pattern
//  Handles tags loading and state management
//

import Foundation
import SwiftUI

@MainActor
class TagsGridViewModel: ObservableObject {
    // MARK: - Published Properties (View State)
    @Published var tags: [Tag] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedTag: Tag?
    
    // MARK: - Dependencies
    private let tagService: TagService
    
    // MARK: - Initialization
    
    init(tagService: TagService) {
        self.tagService = tagService
    }
    
    // MARK: - Public Methods
    
    /// Loads all tags from the service
    func loadTags() {
        debugLog("TagsGridViewModel: loadTags called")
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedTags = try await tagService.fetchTags()
                debugLog("TagsGridViewModel: Successfully fetched \(fetchedTags.count) tags")
                self.tags = fetchedTags
                self.isLoading = false
            } catch {
                debugLog("TagsGridViewModel: Error fetching tags: \(error)")
                self.errorMessage = "Failed to load tags: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    /// Selects a tag
    func selectTag(_ tag: Tag) {
        debugLog("TagsGridViewModel: Tag selected: \(tag.id)")
        selectedTag = tag
    }
    
    /// Clears the selected tag
    func clearSelection() {
        selectedTag = nil
    }
    
    /// Retries loading tags
    func retry() {
        loadTags()
    }
    
    /// Loads tags if not already loaded
    func loadTagsIfNeeded() {
        if tags.isEmpty && !isLoading {
            loadTags()
        }
    }
}

