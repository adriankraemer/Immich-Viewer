# Immich Gallery for Apple TV

A native Apple TV app for browsing your self-hosted Immich photo library with a TV-optimized interface.

## Features

- 🖼️ **Photo Grid View**: Browse your library in a fast, infinite-scrolling grid with infinite pagination
- 👥 **People Recognition**: Jump straight to people Immich detects in your photos with animated thumbnail previews
- 📁 **Album Support**: Navigate personal and shared Immich albums with animated previews
- 🏷️ **Tag Support**: Optional tag tab with animated thumbnail previews showing tag content
- 🗂️ **Folders Tab**: View external library folders (opt-in feature)
- 🔍 **Explore Tab**: Discover stats, locations, and highlights from your library
- 🔎 **Search**: Full-text search across your photo library
- 📺 **Top Shelf Customization**: Pick featured or random photos for the Apple TV top shelf with landscape-only filtering
- 🎬 **Slideshow Mode**: Full-screen slideshow with optional clock overlay, Ken Burns effect, reflections, and auto-start on inactivity
- 👤 **Multi-User Support**: Store multiple accounts and switch instantly between different Immich servers
- 🔐 **Dual Authentication**: Support for both password (JWT) and API key authentication
- 📊 **EXIF Data**: Inspect camera details and location metadata in fullscreen view
- 🎨 **Art Mode**: Automatic dimming based on time of day for ambient display
- 🔒 **Privacy First**: Pure client, keeps credentials local in secure storage
- 🎯 **Customizable Navigation**: Choose between Tabs or Sidebar navigation style

## Requirements

- Apple TV (4th generation or later)
- tvOS 15.0+
- Immich server running and accessible
- Network connectivity between Apple TV and Immich server

## Quick Start

1. **Launch the app** - You'll be prompted to sign in to your Immich server
2. **Enter credentials** - Provide the server URL (e.g., `https://your-immich-server.com`) plus either email & password or an Immich API key
3. **Browse your photos** - Navigate using the Apple TV remote or Siri Remote


## Architecture

### Project Structure

```
Immich Gallery/
├── Components/          # Reusable UI components
│   ├── SharedGridView.swift
│   └── ThumbnailProviders.swift
├── Extensions/          # Swift extensions
│   ├── DateFormatter+Extensions.swift
│   └── GridDisplayableExtensions.swift
├── Models/              # Data models
│   ├── ImmichModels.swift    # Immich API models
│   ├── NavigationStyle.swift # Navigation configuration
│   └── UserModels.swift      # User account models
├── Protocols/           # Protocol definitions
│   └── UserStorage.swift
├── Services/            # Business logic services
│   ├── AlbumService.swift
│   ├── AssetService.swift
│   ├── AuthenticationService.swift
│   ├── ExploreService.swift
│   ├── FolderService.swift
│   ├── NetworkService.swift
│   ├── PeopleService.swift
│   ├── SearchService.swift
│   ├── StatsService.swift
│   ├── TagService.swift
│   ├── ThumbnailCache.swift
│   └── UserManager.swift
├── Storage/             # Data persistence
│   ├── HybridUserStorage.swift    # UserDefaults + Keychain
│   ├── KeychainTokenStorage.swift  # Secure token storage
│   ├── StorageMigration.swift      # Migration utilities
│   └── UserDefaultsStorage.swift   # User data storage
├── Views/               # SwiftUI views
│   ├── AlbumListView.swift
│   ├── AssetGridView.swift
│   ├── ExploreView.swift
│   ├── FoldersView.swift
│   ├── PeopleGridView.swift
│   ├── SearchView.swift
│   ├── Settings/
│   ├── SlideshowView.swift
│   └── ...
├── ContentView.swift   # Main app view
└── Immich_GalleryApp.swift  # App entry point

TopShelfExtension/      # Apple TV Top Shelf extension
└── ContentProvider.swift

Shared/
└── AppConstants.swift  # App-wide constants
```

### Core Architecture

The app follows a **service-oriented architecture** with clear separation of concerns:

#### **Dependency Injection Flow**
```
ContentView
├── UserManager (manages multiple user accounts)
├── NetworkService (HTTP client, depends on UserManager)
├── AuthenticationService (auth state, uses UserManager)
├── AssetService (photo/video operations)
├── AlbumService (album operations)
├── PeopleService (face recognition)
├── TagService (tag management)
├── FolderService (external library folders)
├── ExploreService (stats and discovery)
└── SearchService (full-text search)
```

#### **Data Flow**
```
UI Layer (SwiftUI Views)
    ↓
Business Logic (Services)
    ↓
Network Layer (NetworkService)
    ↓
Storage Layer (HybridUserStorage)
    ↓
Persistence (UserDefaults + Keychain)
```

### Key Components

#### **UserManager**
- Manages multiple user accounts
- Handles authentication (password and API key)
- Provides current user context to all services
- Stores user data in UserDefaults and tokens in Keychain
- Supports seamless user switching

#### **NetworkService**
- Centralized HTTP client
- Handles authentication headers (JWT Bearer or API key)
- Error handling and retry logic
- Supports both JSON and binary data requests

#### **HybridUserStorage**
- Combines UserDefaults (user data) and Keychain (tokens)
- Provides secure token storage while maintaining TopShelf extension compatibility
- Implements `UserStorage` protocol for testability

#### **AssetService**
- Fetches photos and videos with pagination
- Supports filtering by album, person, tag, city, folder
- Handles RAW image conversion (uses server-provided previews)
- Provides thumbnail and full-size image loading

### Authentication System

The app supports two authentication methods:

1. **Password Authentication (JWT)**
   - POST `/api/auth/login` with email/password
   - Returns JWT access token
   - Token stored securely in Keychain

2. **API Key Authentication**
   - GET `/api/users/me` with `x-api-key` header
   - Validates API key and returns user info
   - API key stored securely in Keychain

Both methods support:
- Multiple accounts per server
- Cross-server support (same email on different servers)
- Automatic token validation
- Secure credential storage

### Storage Strategy

#### **User Data** (UserDefaults - App Group)
- Key: `immich_user_{userID}`
- Value: JSON-encoded `SavedUser` object
- Shared with TopShelf extension via App Group

#### **Authentication Tokens** (Keychain)
- Key: `immich_token_{userID}`
- Value: JWT token or API key string
- Secure storage with Keychain access groups

#### **User ID Generation**
- Format: Base64(`email@serverURL`)
- Ensures uniqueness across servers
- Supports same email on different servers

### Top Shelf Extension

The TopShelf extension displays photos on the Apple TV home screen:

- **Features**:
  - Recent photos or random selection
  - Landscape-only filtering for better display
  - Deep linking to open photos in app
  - Carousel or sectioned display styles

- **Architecture**:
  - Runs in separate process
  - Accesses shared UserDefaults for current user
  - Uses Keychain for secure token access
  - Downloads and caches images temporarily

### Settings & Configuration

The app provides extensive customization:

- **Display Settings**:
  - Thumbnail animation toggle
  - Navigation style (Tabs/Sidebar)
  - Default startup tab
  - Tags/Folders tab visibility

- **Slideshow Settings**:
  - Interval duration
  - Auto-start on inactivity
  - Ken Burns effect
  - Reflections effect
  - Clock overlay
  - Art mode (time-based dimming)

- **Top Shelf Settings**:
  - Enable/disable
  - Display style (Carousel/Sectioned)
  - Image selection (Recent/Random)

- **User Management**:
  - Add multiple accounts
  - Switch between users
  - Remove accounts
  - View account details

### Error Handling

The app implements comprehensive error handling:

- **ImmichError** enum for typed errors:
  - `notAuthenticated` (401) - Triggers logout
  - `forbidden` (403) - Triggers logout
  - `serverError` (5xx) - Preserves auth state
  - `networkError` - Connection issues
  - `clientError` (4xx) - Request errors

- **UniversalErrorHandler**:
  - Catches and displays errors in UI
  - Provides context-aware error messages
  - Handles authentication failures gracefully

### Performance Optimizations

- **Thumbnail Caching**: In-memory cache for frequently accessed thumbnails
- **Lazy Loading**: Assets loaded on-demand with pagination
- **Image Optimization**: WebP format for thumbnails, progressive loading
- **Memory Management**: Proper cleanup of timers and observers
- **Background Processing**: Network requests on background threads

### API Integration

The app integrates with Immich's REST API:

- **Endpoints Used**:
  - `/api/auth/login` - Authentication
  - `/api/users/me` - User info
  - `/api/search/metadata` - Asset search
  - `/api/search/random` - Random assets
  - `/api/albums` - Album listing
  - `/api/assets/{id}/thumbnail` - Thumbnails
  - `/api/assets/{id}/original` - Full images
  - `/api/assets/{id}/video/playback` - Video playback
  - `/api/people` - People recognition
  - `/api/tags` - Tag management
  - `/api/folders` - External library folders
  - `/api/stats` - Library statistics

### Deep Linking

The app supports deep linking via custom URL scheme:

- **Scheme**: `immichgallery://`
- **Format**: `immichgallery://asset/{assetId}`
- **Usage**: Opens specific photo in app (used by Top Shelf)

### Thread Safety

- All UI updates wrapped in `MainActor.run`
- Background operations use async/await
- Published properties updated on main thread
- Proper cleanup of timers and observers

## Development

### Prerequisites

- Xcode 15.0 or later
- tvOS 15.0+ SDK
- Apple TV device or simulator for testing

### Project Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/cyyberwolf93/Immich-AppleTV.git
   cd Immich-AppleTV
   ```

2. Open the project:
   ```bash
   open "Immich Gallery.xcodeproj"
   ```

3. Configure App Group (for TopShelf extension):
   - Ensure `AppConstants.appGroupIdentifier` matches your provisioning profile
   - Update in `Shared/AppConstants.swift` if needed

### Code Structure

- **Services**: Business logic and API communication
- **Views**: SwiftUI user interface components
- **Models**: Data structures matching Immich API
- **Storage**: Data persistence layer
- **Components**: Reusable UI components

### Testing

- Unit tests: `Immich GalleryTests/`
- UI tests: `Immich GalleryUITests/`
- Mock services available in `Services/MockImmichService.swift`

### Debugging

- Enable verbose logging in `NetworkService` and `UserManager`
- Check Console.app for network requests and errors
- TopShelf extension logs appear separately in Console

## Troubleshooting

### Known Errors

## License

This project is licensed under the GNU General Public License v3.0 (GPL-3.0). See the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built for the [Immich] (https://immich.app) self-hosted media management system
- Forked from https://github.com/mensadilabs/Immich-Gallery
- Community feedback and contributions
