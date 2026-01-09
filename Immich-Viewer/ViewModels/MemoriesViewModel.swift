import Foundation
import SwiftUI

@MainActor
class MemoriesViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var memories: [Memory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedMemory: Memory?
    
    // MARK: - Dependencies
    private let memoriesService: MemoriesService
    let assetService: AssetService
    
    // MARK: - Initialization
    
    init(memoriesService: MemoriesService, assetService: AssetService) {
        self.memoriesService = memoriesService
        self.assetService = assetService
    }
    
    // MARK: - Public Methods
    
    /// Loads memories if not already loaded
    func loadMemoriesIfNeeded() {
        guard memories.isEmpty && !isLoading else { return }
        loadMemories()
    }
    
    /// Loads all "On This Day" memories
    func loadMemories() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedMemories = try await memoriesService.fetchMemories()
                self.memories = fetchedMemories
                self.isLoading = false
                debugLog("MemoriesViewModel: Loaded \(fetchedMemories.count) memories")
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                debugLog("MemoriesViewModel: Failed to load memories: \(error)")
            }
        }
    }
    
    /// Refreshes memories by invalidating cache and reloading
    func refresh() async {
        memoriesService.invalidateCache()
        
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedMemories = try await memoriesService.fetchMemories()
            self.memories = fetchedMemories
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
    
    /// Selects a memory to view in slideshow
    func selectMemory(_ memory: Memory) {
        debugLog("MemoriesViewModel: Selected memory - \(memory.title)")
        selectedMemory = memory
    }
    
    /// Clears the selected memory
    func clearSelection() {
        selectedMemory = nil
    }
    
    // MARK: - Computed Properties
    
    /// Whether there are any memories to display
    var hasMemories: Bool {
        !memories.isEmpty
    }
    
    /// Today's date formatted for display
    var todayFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: Date())
    }
}
