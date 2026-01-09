import Foundation
import SwiftUI

// MARK: - Explore View Mode

/// View mode for the Explore tab - Places (location-based) or Memories (On This Day)
enum ExploreViewMode: String, CaseIterable {
    case places = "places"
    case memories = "memories"
    
    var displayName: String {
        switch self {
        case .places: return String(localized: "Places")
        case .memories: return String(localized: "Memories")
        }
    }
}

// MARK: - Immich Native Memory API Response Models

/// Response from Immich's native /api/memories endpoint
struct ImmichMemoryResponse: Codable {
    let id: String
    let createdAt: String
    let updatedAt: String
    let deletedAt: String?
    let ownerId: String
    let type: String // "on_this_day"
    let data: ImmichMemoryData
    let isSaved: Bool
    let memoryAt: String
    let seenAt: String?
    let showAt: String?
    let hideAt: String?
    let assets: [ImmichAsset]
}

/// Data payload for a memory (contains year information for "on_this_day" type)
struct ImmichMemoryData: Codable {
    let year: Int
}

// MARK: - Memory Conversion Extension

extension ImmichMemoryResponse {
    /// Parses the memoryAt date string to a Date object
    var memoryDate: Date? {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = dateFormatter.date(from: memoryAt) {
            return date
        }
        
        // Try without fractional seconds
        dateFormatter.formatOptions = [.withInternetDateTime]
        return dateFormatter.date(from: memoryAt)
    }
    
    /// Checks if this memory is for today's date (same month and day)
    func isForToday() -> Bool {
        guard let date = memoryDate else { return false }
        
        let calendar = Calendar.current
        let today = Date()
        
        let memoryMonth = calendar.component(.month, from: date)
        let memoryDay = calendar.component(.day, from: date)
        let todayMonth = calendar.component(.month, from: today)
        let todayDay = calendar.component(.day, from: today)
        
        return memoryMonth == todayMonth && memoryDay == todayDay
    }
    
    /// Converts the Immich API response to our internal Memory model
    func toMemory() -> Memory? {
        guard let date = memoryDate else { return nil }
        
        let currentYear = Calendar.current.component(.year, from: Date())
        let yearsAgo = currentYear - data.year
        
        return Memory(
            id: id,
            yearsAgo: yearsAgo,
            date: date,
            assets: assets
        )
    }
}

// MARK: - Memory Model

/// Represents an "On This Day" memory for a specific year
struct Memory: Identifiable {
    let id: String
    let yearsAgo: Int
    let date: Date
    let assets: [ImmichAsset]
    
    /// The year this memory is from (e.g., 2023)
    var year: Int {
        Calendar.current.component(.year, from: date)
    }
    
    /// Display title like "2 years ago"
    var title: String {
        if yearsAgo == 1 {
            return String(localized: "1 year ago")
        } else {
            return String(localized: "\(yearsAgo) years ago")
        }
    }
    
    /// Formatted date string (e.g., "January 9, 2023")
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    /// Number of photos in this memory
    var photoCount: Int {
        assets.count
    }
    
    /// Cover image asset (first asset or nil if empty)
    var coverAsset: ImmichAsset? {
        assets.first
    }
    
    /// Whether this memory has any photos
    var hasPhotos: Bool {
        !assets.isEmpty
    }
    
    /// Image-only assets (excluding videos)
    var imageAssets: [ImmichAsset] {
        assets.filter { $0.type == .image }
    }
}

