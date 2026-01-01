//
//  NavigationStyle.swift
//  Immich-AppleTV
//

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
}
