import Foundation

enum NavigationStyle: String, CaseIterable {
    case tabs
    case sidebar
    
    var displayName: String {
        switch self {
        case .tabs:
            return "Tabs"
        case .sidebar:
            return "Sidebar"
        }
    }
    
    var localizedDisplayName: String {
        switch self {
        case .tabs:
            return String(localized: "Tabs")
        case .sidebar:
            return String(localized: "Sidebar")
        }
    }
}
