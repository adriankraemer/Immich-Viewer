import Foundation

class FolderService: ObservableObject {
    private let networkService: NetworkService
    
    // Thread-safe cache for folder asset dates to avoid repeated API calls
    private let folderDateCache = FolderDateCache()
    
    init(networkService: NetworkService) {
        self.networkService = networkService
    }
    
    // MARK: - Thread-safe Cache Actor
    
    private actor FolderDateCache {
        private var cache: [String: Date] = [:]
        
        func get(_ key: String) -> Date? {
            cache[key]
        }
        
        func set(_ key: String, date: Date) {
            cache[key] = date
        }
        
        func clear() {
            cache.removeAll()
        }
    }
    
    func fetchUniquePaths() async throws -> [ImmichFolder] {
        let paths: [String] = try await networkService.makeRequest(
            endpoint: "/api/view/folder/unique-paths",
            method: .GET,
            responseType: [String].self
        )
        
        return paths.map { ImmichFolder(path: $0) }
    }
    
    // MARK: - Tree View Support
    
    /// Builds a hierarchical tree structure from flat folder paths
    /// Example: ["/photos/2024", "/photos/2024/vacation", "/documents"]
    /// becomes a tree with "photos" containing "2024" containing "vacation", and "documents" at root
    func buildFolderTree(from folders: [ImmichFolder]) -> [ImmichFolder] {
        // Build a dictionary of path -> folder for quick lookup
        var foldersByPath: [String: ImmichFolder] = [:]
        for folder in folders {
            foldersByPath[folder.path] = folder
        }
        
        // Find all unique path components and build tree
        var rootFolders: [ImmichFolder] = []
        var processedPaths: Set<String> = []
        
        // Sort paths to process parents before children
        let sortedPaths = folders.map { $0.path }.sorted()
        
        for path in sortedPaths {
            let components = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .components(separatedBy: "/")
                .filter { !$0.isEmpty }
            
            guard !components.isEmpty else { continue }
            
            // Build path incrementally and ensure each level exists
            var currentPath = ""
            for (index, component) in components.enumerated() {
                let previousPath = currentPath
                currentPath = currentPath.isEmpty ? "/\(component)" : "\(currentPath)/\(component)"
                
                // Skip if we've already processed this path
                if processedPaths.contains(currentPath) {
                    continue
                }
                processedPaths.insert(currentPath)
                
                // Create or get the folder for this path
                var folder = foldersByPath[currentPath] ?? ImmichFolder(path: currentPath)
                folder.children = [] // Initialize children array
                
                if index == 0 {
                    // Root level folder
                    if !rootFolders.contains(where: { $0.path == currentPath }) {
                        rootFolders.append(folder)
                    }
                } else {
                    // Child folder - find parent and add
                    if let parentIndex = rootFolders.firstIndex(where: { $0.path == previousPath }) {
                        var parent = rootFolders[parentIndex]
                        var children = parent.children ?? []
                        if !children.contains(where: { $0.path == currentPath }) {
                            children.append(folder)
                            parent.children = children
                            rootFolders[parentIndex] = parent
                        }
                    } else {
                        // Need to find parent in nested structure
                        rootFolders = addChildToTree(rootFolders, parentPath: previousPath, child: folder)
                    }
                }
            }
        }
        
        return sortFolderTree(rootFolders)
    }
    
    /// Recursively adds a child folder to the correct parent in the tree
    private func addChildToTree(_ folders: [ImmichFolder], parentPath: String, child: ImmichFolder) -> [ImmichFolder] {
        var result = folders
        for (index, folder) in result.enumerated() {
            if folder.path == parentPath {
                var updatedFolder = folder
                var children = updatedFolder.children ?? []
                if !children.contains(where: { $0.path == child.path }) {
                    children.append(child)
                    updatedFolder.children = children
                    result[index] = updatedFolder
                }
                return result
            } else if let children = folder.children, !children.isEmpty {
                var updatedFolder = folder
                updatedFolder.children = addChildToTree(children, parentPath: parentPath, child: child)
                result[index] = updatedFolder
            }
        }
        return result
    }
    
    /// Sorts folder tree alphabetically at each level
    private func sortFolderTree(_ folders: [ImmichFolder]) -> [ImmichFolder] {
        var sorted = folders.sorted { $0.primaryTitle.localizedCaseInsensitiveCompare($1.primaryTitle) == .orderedAscending }
        for (index, folder) in sorted.enumerated() {
            if let children = folder.children, !children.isEmpty {
                var updatedFolder = folder
                updatedFolder.children = sortFolderTree(children)
                sorted[index] = updatedFolder
            }
        }
        return sorted
    }
    
    // MARK: - Timeline View Support
    
    /// Fetches the most recent asset date for a folder
    func fetchMostRecentAssetDate(for folderPath: String) async throws -> Date? {
        // Check cache first
        if let cachedDate = await folderDateCache.get(folderPath) {
            return cachedDate
        }
        
        // Fetch the most recent asset in this folder
        let searchRequest: [String: Any] = [
            "page": 1,
            "size": 1,
            "order": "desc",
            "originalPath": folderPath
        ]
        
        let result: SearchResponse = try await networkService.makeRequest(
            endpoint: "/api/search/metadata",
            method: .POST,
            body: searchRequest,
            responseType: SearchResponse.self
        )
        
        guard let firstAsset = result.assets.items.first else {
            return nil
        }
        
        // Parse the date from the asset
        let date = parseAssetDate(firstAsset)
        
        // Cache the result
        if let date = date {
            await folderDateCache.set(folderPath, date: date)
        }
        
        return date
    }
    
    /// Fetches folder info including most recent date for multiple folders (batch operation)
    func fetchFoldersWithDates(_ folders: [ImmichFolder]) async -> [ImmichFolder] {
        var updatedFolders: [ImmichFolder] = []
        
        // Process folders in parallel with a limit to avoid overwhelming the server
        await withTaskGroup(of: (String, Date?).self) { group in
            for folder in folders {
                group.addTask {
                    let date = try? await self.fetchMostRecentAssetDate(for: folder.path)
                    return (folder.path, date)
                }
            }
            
            var datesByPath: [String: Date] = [:]
            for await (path, date) in group {
                if let date = date {
                    datesByPath[path] = date
                }
            }
            
            // Update folders with dates
            for folder in folders {
                var updatedFolder = folder
                updatedFolder.mostRecentAssetDate = datesByPath[folder.path]
                updatedFolders.append(updatedFolder)
            }
        }
        
        return updatedFolders
    }
    
    /// Groups folders by time period for timeline view
    /// Uses flexible grouping: day for recent, month for this year, year for older
    func groupFoldersForTimeline(_ folders: [ImmichFolder]) -> [FolderTimelineGroup] {
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        
        // Separate folders with and without dates
        let foldersWithDates = folders.filter { $0.mostRecentAssetDate != nil }
        let foldersWithoutDates = folders.filter { $0.mostRecentAssetDate == nil }
        
        // Group folders by appropriate time period
        var groupedFolders: [String: [ImmichFolder]] = [:]
        var groupDates: [String: Date] = [:]
        
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "MMMM d, yyyy"
        
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM yyyy"
        
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"
        
        for folder in foldersWithDates {
            guard let date = folder.mostRecentAssetDate else { continue }
            
            let groupKey: String
            let year = calendar.component(.year, from: date)
            
            if date >= thirtyDaysAgo {
                // Recent: group by day
                groupKey = dayFormatter.string(from: date)
            } else if year == currentYear {
                // This year: group by month
                groupKey = monthFormatter.string(from: date)
            } else {
                // Older: group by year
                groupKey = yearFormatter.string(from: date)
            }
            
            if groupedFolders[groupKey] == nil {
                groupedFolders[groupKey] = []
                groupDates[groupKey] = date
            }
            groupedFolders[groupKey]?.append(folder)
            
            // Keep the most recent date for sorting
            if let existingDate = groupDates[groupKey], date > existingDate {
                groupDates[groupKey] = date
            }
        }
        
        // Create timeline groups sorted by date (newest first)
        var timelineGroups: [FolderTimelineGroup] = []
        
        let sortedKeys = groupedFolders.keys.sorted { key1, key2 in
            let date1 = groupDates[key1] ?? .distantPast
            let date2 = groupDates[key2] ?? .distantPast
            return date1 > date2
        }
        
        for key in sortedKeys {
            if let folders = groupedFolders[key] {
                let sortedFolders = folders.sorted { 
                    ($0.mostRecentAssetDate ?? .distantPast) > ($1.mostRecentAssetDate ?? .distantPast)
                }
                let group = FolderTimelineGroup(
                    title: key,
                    folders: sortedFolders,
                    startDate: groupDates[key]
                )
                timelineGroups.append(group)
            }
        }
        
        // Add folders without dates at the end
        if !foldersWithoutDates.isEmpty {
            let unknownGroup = FolderTimelineGroup(
                title: String(localized: "Unknown Date"),
                folders: foldersWithoutDates.sorted { $0.primaryTitle < $1.primaryTitle },
                startDate: nil
            )
            timelineGroups.append(unknownGroup)
        }
        
        return timelineGroups
    }
    
    /// Clears the folder date cache
    func clearCache() async {
        await folderDateCache.clear()
    }
    
    // MARK: - Private Helpers
    
    private static let isoFormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    private func parseAssetDate(_ asset: ImmichAsset) -> Date? {
        // Try EXIF date first (most accurate)
        if let dateString = asset.exifInfo?.dateTimeOriginal,
           let date = parseDate(dateString) {
            return date
        }
        
        // Fall back to file dates
        if let date = parseDate(asset.fileCreatedAt) {
            return date
        }
        if let date = parseDate(asset.localDateTime) {
            return date
        }
        if let date = parseDate(asset.fileModifiedAt) {
            return date
        }
        
        return nil
    }
    
    private func parseDate(_ value: String?) -> Date? {
        guard let value = value else { return nil }
        if let date = FolderService.isoFormatterWithFractional.date(from: value) {
            return date
        }
        return FolderService.isoFormatter.date(from: value)
    }
}
