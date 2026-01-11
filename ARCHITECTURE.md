# Architecture Documentation

This document provides a technical overview of the Immich-Viewer architecture for developers and contributors.

## Table of Contents

1. [Overview](#overview)
2. [Architecture Patterns](#architecture-patterns)
3. [Service Layer](#service-layer)
4. [Data Models](#data-models)
5. [Storage Architecture](#storage-architecture)
6. [Authentication Flow](#authentication-flow)
7. [Network Layer](#network-layer)
8. [UI Architecture](#ui-architecture)
9. [Top Shelf Extension](#top-shelf-extension)
10. [Performance Considerations](#performance-considerations)

---

## Overview

Immich-Viewer follows a **service-oriented MVVM architecture** with clear separation between:

- **Presentation Layer**: SwiftUI views and view models
- **Business Logic Layer**: Service classes
- **Data Layer**: Storage and network abstractions
- **Infrastructure Layer**: Caching, persistence, and utilities

---

## Architecture Patterns

### Dependency Injection

All services are initialized in `ContentView` and passed down to child views:

```
ContentView
├── UserManager (centralized user management)
├── NetworkService (depends on UserManager)
├── AuthenticationService (depends on NetworkService + UserManager)
└── Feature Services (depend on NetworkService)
    ├── AssetService
    ├── AlbumService
    ├── PeopleService
    ├── TagService
    ├── FolderService
    ├── ExploreService
    ├── MapService
    ├── SearchService
    ├── MemoriesService
    └── StatsService
```

### Observable Pattern

Services and view models use `@Published` properties and `ObservableObject` to notify views of state changes:

- `UserManager`: `@Published var savedUsers`, `@Published var currentUser`
- `AuthenticationService`: `@Published var isAuthenticated`, `@Published var currentUser`
- View models: Loading states, error messages, data collections

### Protocol-Oriented Design

Storage abstraction via protocols enables testing and future migration:

```swift
protocol UserStorage {
    func saveUser(_ user: SavedUser) throws
    func loadUsers() -> [SavedUser]
    func removeUser(withId id: String) throws
}
```

---

## Service Layer

### UserManager

Centralized user account management.

**Responsibilities:**
- Managing multiple user accounts
- Authentication (password and API key)
- User switching and persistence
- Token management via Keychain

### NetworkService

HTTP client for Immich API.

**Key Features:**
- Dynamic header switching (JWT vs API key)
- Automatic credential loading from UserManager
- Comprehensive error handling and classification

### AuthenticationService

Authentication state management.

**Responsibilities:**
- Tracking authentication status
- User info fetching and validation
- Token validation and logout handling

### AssetService

Photo and video operations.

**Key Methods:**
- `fetchAssets()` — Search with filters (album, person, tag, city, folder)
- `fetchRandomAssets()` — Random selection for slideshows
- `loadImage()` — Thumbnail loading with caching
- `loadFullImage()` — Full-size image with RAW support
- `loadVideoURL()` — Video playback URL construction

**RAW Support:** Detects RAW formats (DNG, CR2, NEF, ARW, ORF, RAF) and uses server-provided previews.

### AlbumService

Album operations including personal and shared albums.

### PeopleService

Face recognition and people management with animated thumbnail previews.

### TagService

Tag management and tag-based photo retrieval.

### FolderService

Folder navigation with grid, tree, and timeline view support.

### ExploreService

Discovery features including city-based grouping and statistics.

### MapService

Geographic data and map operations.

**Key Methods:**
- `fetchMapMarkers()` — Lightweight markers for fast initial load
- `fetchAssetsInRegion()` — On-demand asset loading for specific regions
- 5-minute cache for map data

### MemoriesService

"On This Day" memories feature, fetching photos from previous years on the current date.

### SearchService

AI-powered contextual search across assets using Immich's CLIP integration.

### StatsService

Library statistics including photo/video counts and storage usage.

---

## Data Models

### ImmichAsset

Core model representing a photo or video:

```swift
struct ImmichAsset: Codable, Identifiable, Equatable {
    let id: String
    let type: AssetType  // IMAGE, VIDEO, AUDIO, OTHER
    let isFavorite: Bool
    let exifInfo: ExifInfo?
    let people: [Person]
    // ... metadata fields
}
```

### SavedUser

User account model for multi-user support:

```swift
struct SavedUser: Codable, Identifiable {
    let id: String  // Base64(email@serverURL)
    let email: String
    let name: String
    let serverURL: String
    let authType: AuthType  // .jwt or .apiKey
    let profileImageData: Data?
}
```

### Memory

"On This Day" memory model:

```swift
struct Memory: Identifiable {
    let id: String
    let title: String
    let date: Date
    let assets: [ImmichAsset]
    var coverAsset: ImmichAsset?
}
```

### GridDisplayable Protocol

Unified interface for grid items (albums, people, tags, folders, continents):

```swift
protocol GridDisplayable: Identifiable {
    var primaryTitle: String { get }
    var secondaryTitle: String? { get }
    var thumbnailId: String? { get }
    var itemCount: Int? { get }
}
```

---

## Storage Architecture

### HybridUserStorage

Combines two storage mechanisms:

1. **UserDefaults** (App Group)
   - User account data and settings
   - Shared with TopShelf extension

2. **Keychain**
   - Authentication tokens (JWT or API keys)
   - Secure, encrypted storage

### Storage Keys

- User data: `immich_user_{userID}` → JSON-encoded SavedUser
- Tokens: Keychain key `immich_token_{userID}` → Token string
- Current user: `currentActiveUserId` in shared UserDefaults

### Migration System

`StorageMigration.swift` handles one-time migration from standard UserDefaults to App Group for backward compatibility.

---

## Authentication Flow

### Password Authentication

1. User enters email + password
2. POST `/api/auth/login` → Returns JWT token
3. Fetch user profile image
4. Create and save SavedUser
5. Save token to Keychain
6. Set as current user
7. Update NetworkService credentials

### API Key Authentication

1. User enters email + API key
2. GET `/api/users/me` (with `x-api-key` header) → Validates key
3. Fetch user profile image
4. Create SavedUser with `authType: .apiKey`
5. Save API key to Keychain
6. Set as current user

### User Switching

1. Load token from Keychain for selected user
2. Clear HTTP cookies for previous server
3. Update currentUser in UserManager
4. Update NetworkService credentials
5. Post `refreshAllTabs` notification
6. Fetch new user info

---

## Network Layer

### Request Building

`NetworkService.buildAuthenticatedRequest()`:
1. Validates credentials exist
2. Constructs full URL (baseURL + endpoint)
3. Sets HTTP method and auth header
4. Adds JSON body if provided

### Error Classification

```swift
enum ImmichError: Error {
    case notAuthenticated  // 401 - triggers logout
    case forbidden         // 403 - triggers logout
    case serverError(Int)  // 5xx - preserves auth
    case networkError      // Connection issues
    case clientError(Int)  // 4xx - request error
    case invalidURL        // Malformed URL
}
```

---

## UI Architecture

### View Hierarchy

```
Immich_ViewerApp
└── ContentView
    ├── SignInView (if not authenticated)
    └── TabView (if authenticated)
        ├── AssetGridView (Photos)
        ├── AlbumListView (optional)
        ├── PeopleGridView
        ├── TagsGridView (optional)
        ├── FoldersView (optional)
        ├── ExploreView
        │   ├── Places (continents → countries → cities)
        │   └── Memories (On This Day)
        ├── WorldMapView
        ├── SearchView
        └── SettingsView
            ├── Interface
            ├── Slideshow
            ├── Sorting
            ├── Top Shelf
            ├── Account
            ├── Statistics
            └── About
```

### Navigation Styles

Two navigation styles supported via `NavigationStyle` enum:
- **Tabs**: Traditional tab bar navigation
- **Sidebar**: Sidebar-style navigation (tvOS 15+)

### View Models

View models bridge services and views:

| ViewModel | Purpose |
|-----------|---------|
| `AssetGridViewModel` | Asset grid state and pagination |
| `SlideshowViewModel` | Slideshow logic, Ken Burns effect, timing |
| `WorldMapViewModel` | Map markers, region loading, clustering |
| `ExploreViewModel` | Statistics and continent-based exploration |
| `MemoriesViewModel` | "On This Day" memories loading |
| `SearchViewModel` | Search queries and results |
| `FullScreenImageViewModel` | Full-screen image viewing and navigation |
| `SignInViewModel` | Authentication form logic |

### State Management

- `@StateObject`: For service instances (created once)
- `@State`: For local view state
- `@AppStorage`: For UserDefaults-backed settings
- `NotificationCenter`: For cross-view communication (tab refresh, slideshow triggers)

---

## Top Shelf Extension

### Architecture

Separate process that:
1. Loads current user from shared UserDefaults
2. Retrieves token from Keychain
3. Fetches photos from Immich API
4. Downloads and processes images
5. Creates `TVTopShelfContent`

### Content Types

- **Carousel**: Horizontal scrolling fullscreen carousel
- **Sectioned**: Compact grid-style sections

### Image Selection

- **Recent**: Latest landscape photos
- **Random**: Random landscape selection

### Deep Linking

Photos link to: `immichgallery://asset/{assetId}`
- Opens app and navigates to specific photo
- Handled in `Immich_ViewerApp.onOpenURL()`

---

## Performance Considerations

### Image Loading

- **Thumbnails**: WebP format, cached in memory and disk
- **Full Images**: Progressive loading with fallback
- **RAW Images**: Server-converted previews
- **Video Thumbnails**: Cached preview images

### Caching Strategy

| Cache | Purpose | Duration |
|-------|---------|----------|
| `ThumbnailCache` | In-memory + disk cache for thumbnails | Session + persistent |
| `StatsCache` | Library statistics | Session |
| `MapService` | Map markers | 5 minutes |
| TopShelf | Temporary file cache | Cleared on each update |

### Memory Management

- Proper cleanup of timers and observers
- Image data released when not in use
- Pagination prevents loading entire library
- Lazy loading for map markers and assets
- Batch processing for large datasets

### Background Processing

- Network requests on background threads
- UI updates on main thread (`@MainActor`)
- Async/await for concurrent operations
- Background image processing and color extraction

### Map Performance

- Lightweight marker loading for fast initial render
- On-demand asset loading when zooming into regions
- Clustering to reduce annotation count
- Coordinate validation to prevent invalid markers

---

## Thread Safety

### Main Thread Requirements

All UI updates must be on main thread:

```swift
await MainActor.run {
    self.isAuthenticated = true
    self.currentUser = user
}
```

### Background Operations

Network and storage operations run on background threads:

```swift
Task {
    let result = try await service.fetchData()
    await MainActor.run {
        self.data = result
    }
}
```

---

## Additional Features

### Auto-Slideshow

Automatic slideshow activation after user inactivity:
- Configurable timeout (in minutes, 0 = disabled)
- Switches to Photos tab automatically
- Timer resets on any user interaction
- Controlled via `NotificationCenter`

### Deep Linking

URL scheme support for opening specific assets:
- Format: `immichgallery://asset/{assetId}`
- Handled in `Immich_ViewerApp.onOpenURL()`
- Posts notification to `ContentView` for asset navigation

### Slideshow Features

- **Ken Burns Effect**: Pan and zoom animations
- **Ambilight Background**: Dynamic color-matched background
- **Shuffle Mode**: Randomize photo order
- **Reflections**: Optional reflection effects
- **Custom Intervals**: 3 seconds to 2 minutes
- **Pause/Resume**: Play/Pause button control

### Location Hierarchy

Hierarchical location browsing:
- **World Map**: Global view with clustered photo locations
- **Continent View**: Photos grouped by continent
- **Country View**: Photos within a specific country
- **City View**: Photos within a specific city

Location data is extracted from EXIF metadata.
