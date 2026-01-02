# Architecture Documentation

This document provides a detailed overview of the Immich-AppleTV architecture, design patterns, and implementation details.

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
10. [Error Handling](#error-handling)
11. [Performance Considerations](#performance-considerations)

## Overview

Immich-AppleTV follows a **service-oriented architecture** with clear separation between:
- **Presentation Layer**: SwiftUI views
- **Business Logic Layer**: Service classes
- **Data Layer**: Storage and network abstractions
- **Infrastructure Layer**: Network, caching, persistence

## Architecture Patterns

### Dependency Injection

All services are initialized in `ContentView` and passed down to child views:

```swift
ContentView
├── UserManager (singleton-like, shared across app)
├── NetworkService (depends on UserManager)
├── AuthenticationService (depends on NetworkService + UserManager)
└── Feature Services (depend on NetworkService)
    ├── AssetService
    ├── AlbumService
    ├── PeopleService
    └── ...
```

### Observable Pattern

Services use `@Published` properties and `ObservableObject` to notify views of state changes:

- `UserManager`: `@Published var savedUsers`, `@Published var currentUser`
- `AuthenticationService`: `@Published var isAuthenticated`, `@Published var currentUser`
- Services are injected as `@StateObject` in views

### Protocol-Oriented Design

Storage abstraction via protocols enables:
- Easy testing with mock implementations
- Future migration paths (e.g., UserDefaults → Keychain)
- Clear contracts between layers

```swift
protocol UserStorage {
    func saveUser(_ user: SavedUser) throws
    func loadUsers() -> [SavedUser]
    func removeUser(withId id: String) throws
    // ...
}
```

## Service Layer

### UserManager

**Purpose**: Centralized user account management

**Responsibilities**:
- Managing multiple user accounts
- Authentication (password and API key)
- User switching and persistence
- Token management

**Key Methods**:
- `authenticateWithCredentials()` - Password-based login
- `authenticateWithApiKey()` - API key-based login
- `switchToUser()` - Change active user
- `removeUser()` - Delete user account

**Storage**:
- User data: UserDefaults (App Group)
- Tokens: Keychain (secure storage)

### NetworkService

**Purpose**: HTTP client for Immich API

**Responsibilities**:
- Building authenticated requests
- Handling different auth types (JWT vs API key)
- Error classification and handling
- Response processing

**Key Features**:
- Dynamic header switching based on auth type
- Automatic credential loading from UserManager
- Comprehensive error handling

**Auth Header Logic**:
```swift
if currentAuthType == .apiKey {
    request.setValue(accessToken, forHTTPHeaderField: "x-api-key")
} else {
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
}
```

### AuthenticationService

**Purpose**: Authentication state management

**Responsibilities**:
- Tracking authentication status
- User info fetching
- Token validation
- Logout handling

**State Management**:
- `isAuthenticated`: Boolean flag for UI state
- `currentUser`: Owner object with user details
- Automatic token validation on init

### AssetService

**Purpose**: Photo and video operations

**Key Methods**:
- `fetchAssets()` - Search with filters (album, person, tag, city, folder)
- `fetchRandomAssets()` - Random selection for slideshows
- `loadImage()` - Thumbnail loading
- `loadFullImage()` - Full-size image with RAW support
- `loadVideoURL()` - Video playback URL

**RAW Image Handling**:
- Detects RAW formats by MIME type
- Falls back to server-provided preview size
- Handles formats: DNG, CR2, NEF, ARW, ORF, RAF, etc.

### AlbumService

**Purpose**: Album operations

**Key Methods**:
- `fetchAlbums()` - Get all albums (personal + shared)
- `getAlbumInfo()` - Detailed album information
- `loadAlbumThumbnail()` - Album cover image

### PeopleService

**Purpose**: Face recognition and people management

**Features**:
- Fetch all recognized people
- Get photos for specific person
- Animated thumbnail previews

### TagService

**Purpose**: Tag management

**Features**:
- Fetch all tags
- Get photos for specific tag
- Animated thumbnail previews

### FolderService

**Purpose**: Folder operations

**Features**:
- Fetch all folders
- Get photos for specific folder
- Animated thumbnail previews

### ExploreService

**Purpose**: Discovery and statistics

**Features**:
- Library statistics (total photos, videos)
- City-based photo grouping
- Highlights and recommendations

### MapService

**Purpose**: Geographic data and map operations

**Features**:
- Fetch lightweight map markers for fast initial load
- On-demand asset loading for specific regions
- Cache management for map data
- Support for `/api/map/markers` endpoint with fallback to metadata search
- Geographic region filtering

**Key Methods**:
- `fetchMapMarkers()` - Fast initial marker load with caching
- `fetchAssetsInRegion()` - Load assets within geographic bounds
- `fetchAssetsById()` - Batch fetch assets by ID
- `fetchGeodata()` - Legacy full data fetch (heavyweight)

### StatsService

**Purpose**: Library statistics and analytics

**Features**:
- Total photo and video counts
- Storage statistics
- Cached statistics for performance

### SearchService

**Purpose**: Full-text search

**Features**:
- Search across assets and albums
- Faceted search results
- Pagination support

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
    let createdAt: Date
    let profileImageData: Data?
}
```

### GridDisplayable Protocol

Unified interface for grid items (albums, people, tags, folders):

```swift
protocol GridDisplayable: Identifiable {
    var primaryTitle: String { get }
    var secondaryTitle: String? { get }
    var thumbnailId: String? { get }
    var itemCount: Int? { get }
    // ...
}
```

## Storage Architecture

### HybridUserStorage

Combines two storage mechanisms:

1. **UserDefaults** (App Group)
   - User account data
   - Settings and preferences
   - Shared with TopShelf extension

2. **Keychain**
   - Authentication tokens (JWT or API keys)
   - Secure, encrypted storage
   - Accessible by app and extension

### Storage Keys

**User Data**:
- `immich_user_{userID}` → JSON-encoded SavedUser

**Tokens**:
- Keychain key: `immich_token_{userID}` → Token string

**Current User**:
- `currentActiveUserId` → String (in shared UserDefaults)

### Migration System

`StorageMigration.swift` handles:
- One-time migration from standard UserDefaults to App Group
- Legacy key cleanup
- Backward compatibility

## Authentication Flow

### Password Authentication

```
1. User enters email + password
2. POST /api/auth/login
   → Returns AuthResponse with JWT token
3. Fetch user profile image
4. Create SavedUser object
5. Save user to UserDefaults
6. Save token to Keychain
7. Set as current user
8. Update NetworkService credentials
9. Fetch user info from server
10. Set isAuthenticated = true
```

### API Key Authentication

```
1. User enters email + API key
2. GET /api/users/me (with x-api-key header)
   → Validates key and returns User object
3. Fetch user profile image
4. Create SavedUser object (authType: .apiKey)
5. Save user to UserDefaults
6. Save API key to Keychain
7. Set as current user
8. Update NetworkService credentials
9. Set isAuthenticated = true
```

### User Switching

```
1. User selects different account
2. Load token from Keychain for selected user
3. Clear HTTP cookies for previous server
4. Update currentUser in UserManager
5. Update NetworkService credentials
6. Refresh all tabs (via NotificationCenter)
7. Fetch new user info
```

## Network Layer

### Request Building

`NetworkService.buildAuthenticatedRequest()`:
1. Validates credentials exist
2. Constructs full URL (baseURL + endpoint)
3. Sets HTTP method
4. Adds auth header (JWT or API key)
5. Adds JSON body if provided

### Response Processing

`NetworkService.processResponse()`:
1. Validates HTTP response
2. Checks status code
3. Maps to ImmichError types:
   - 401 → `notAuthenticated` (triggers logout)
   - 403 → `forbidden` (triggers logout)
   - 5xx → `serverError` (preserves auth)
   - 4xx → `clientError`
   - Network failures → `networkError`

### Error Classification

```swift
enum ImmichError: Error {
    case notAuthenticated  // 401 - logout
    case forbidden         // 403 - logout
    case serverError(Int)  // 5xx - preserve auth
    case networkError      // Connection issues
    case clientError(Int)  // 4xx - request error
    case invalidURL        // Malformed URL
}
```

## UI Architecture

### View Hierarchy

```
Immich_AppleTVApp
└── ContentView
    ├── SignInView (if not authenticated)
    └── TabView (if authenticated)
        ├── AssetGridView (Photos)
        ├── AlbumListView (optional)
        ├── PeopleGridView
        ├── TagsGridView (optional)
        ├── FoldersView (optional)
        ├── ExploreView
        ├── WorldMapView
        ├── SearchView
        └── SettingsView
```

### Navigation Styles

Two navigation styles supported:
- **Tabs**: Traditional tab bar navigation
- **Sidebar**: Sidebar-style navigation (tvOS 15+)

### State Management

- **@StateObject**: For service instances (created once)
- **@State**: For local view state
- **@AppStorage**: For UserDefaults-backed settings
- **NotificationCenter**: For cross-view communication

### View Models

View models bridge services and views:
- **AssetGridViewModel**: Manages asset grid state and pagination
- **SlideshowViewModel**: Handles slideshow logic, Ken Burns effect, timing
- **WorldMapViewModel**: Manages map markers, region loading, asset selection
- **ExploreViewModel**: Handles statistics and city-based exploration
- **SearchViewModel**: Manages search queries and results
- **FullScreenImageViewModel**: Controls full-screen image viewing and navigation
- **StatsViewModel**: Manages library statistics display

### Error Handling

`UniversalErrorHandler` view modifier:
- Catches errors from async operations
- Displays user-friendly error messages
- Handles authentication failures gracefully

## Top Shelf Extension

### Architecture

Separate process that:
1. Loads current user from shared UserDefaults
2. Retrieves token from Keychain
3. Fetches photos from Immich API
4. Downloads and processes images
5. Creates TVTopShelfContent

### Content Types

- **Carousel**: Horizontal scrolling carousel
- **Sectioned**: Grid-style sections

### Image Selection

- **Recent**: Latest photos (landscape only)
- **Random**: Random selection (landscape only)

### Configuration

Top Shelf settings stored in UserDefaults:
- `enableTopShelf`: Enable/disable Top Shelf
- `topShelfStyle`: Carousel or sectioned style
- `topShelfImageSelection`: Recent or random photos

### Deep Linking

Photos link to: `immichgallery://asset/{assetId}`
- Opens app and navigates to specific photo
- Handled in `ContentView.onOpenURL()`

## Error Handling

### Error Propagation

```
Network Request
    ↓ (throws ImmichError)
Service Method
    ↓ (re-throws or converts)
View Async Task
    ↓ (caught by errorBoundary)
UniversalErrorHandler
    ↓ (displays to user)
```

### Error Recovery

- **Authentication Errors**: Automatic logout and sign-in prompt
- **Network Errors**: Retry with user notification
- **Server Errors**: Preserve auth state, show error message
- **Client Errors**: Display specific error message

### Logging

Comprehensive logging throughout:
- Network requests/responses
- Authentication state changes
- User operations
- Error conditions

## Performance Considerations

### Image Loading

- **Thumbnails**: WebP format, cached in memory
- **Full Images**: Progressive loading
- **RAW Images**: Server-converted previews
- **Video Thumbnails**: Cached video preview images

### Caching Strategy

- **ThumbnailCache**: In-memory cache for frequently accessed thumbnails
- **StatsCache**: Cached library statistics
- **MapService Cache**: 5-minute cache for map markers
- **TopShelf**: Temporary file cache (cleared on each update)

### Memory Management

- Proper cleanup of timers and observers
- Image data released when not in use
- Pagination prevents loading entire library
- Lazy loading for map markers and assets
- Batch processing for large datasets

### Background Processing

- Network requests on background threads
- UI updates on main thread (MainActor)
- Async/await for concurrent operations
- Background image processing and color extraction

### Map Performance

- Lightweight marker loading for fast initial render
- On-demand asset loading when zooming into regions
- Batch fetching to minimize API calls
- Coordinate validation to prevent invalid markers

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

Network and storage operations on background:
```swift
Task {
    let result = try await service.fetchData()
    await MainActor.run {
        self.data = result
    }
}
```

## Additional Features

### Auto-Slideshow

Automatic slideshow activation after user inactivity:
- Configurable timeout (in minutes, 0 = disabled)
- Switches to Photos tab automatically
- Starts slideshow after tab transition
- Timer resets on any user interaction
- Controlled via `NotificationCenter` for pause/resume

### Deep Linking

URL scheme support for opening specific assets:
- Format: `immichgallery://asset/{assetId}`
- Handled in `Immich_AppleTVApp.onOpenURL()`
- Posts notification to `ContentView` for asset navigation
- Automatically switches to Photos tab and highlights asset

### Slideshow Features

- **Ken Burns Effect**: Pan and zoom animations with configurable enable/disable
- **Shuffle Mode**: Randomize photo order
- **Reflections**: Optional reflection effects
- **Custom Intervals**: User-configurable timing
- **Background Colors**: Customizable slideshow background
- **Pause/Resume**: User control during slideshow

### Location Hierarchy

Hierarchical location browsing:
- **World Map**: Global view with all photo locations
- **Continent View**: Photos grouped by continent
- **Country View**: Photos within a specific country
- **City View**: Photos within a specific city
- Location data extracted from EXIF metadata