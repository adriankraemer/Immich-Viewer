# MVVM Code Quality Review

This document categorizes MVVM violations and improvements by priority level.

## 🔴 TOP PRIORITY - Critical MVVM Violations

### 1. Views Directly Accessing Services (Major Violation)
**Issue**: Many views directly observe and call services instead of using ViewModels.

**Affected Views**:
- `AssetGridView` - Directly uses `AssetService`, `AuthenticationService`
- `AlbumListView` - Directly uses `AlbumService`, `AssetService`, `AuthenticationService`
- `PeopleGridView` - Directly uses `PeopleService`, `AssetService`, `AuthenticationService`
- `TagsGridView` - Directly uses `TagService`, `AssetService`, `AuthenticationService`
- `FoldersView` - Directly uses `FolderService`, `AssetService`, `AuthenticationService`
- `SearchView` - Directly uses `SearchService`, `AssetService`, `AuthenticationService`
- `StatsView` - Directly uses `StatsService`
- `SignInView` - Directly uses `AuthenticationService`, `UserManager`
- `FullScreenImageView` - Directly uses `AssetService`, `AuthenticationService`
- `VideoPlayerView` - Directly uses `AssetService`, `AuthenticationService`
- `SlideshowView` - Creates services internally (see #2)

**Impact**: 
- Views contain business logic
- Difficult to test
- Tight coupling between UI and services
- Violates separation of concerns

**Solution**: Create ViewModels for each view that encapsulate service interactions.

---

### 2. Business Logic in Views (Major Violation)
**Issue**: Views contain async/await logic, error handling, state management, and data transformation.

**Examples**:

**AssetGridView.swift** (lines 260-425):
- `loadAssets()` - Contains async business logic
- `loadMoreAssets()` - Pagination logic in view
- `extractPageFromNextPage()` - Data transformation in view
- `handleDeepLinkAsset()` - Navigation logic in view

**AlbumListView.swift** (lines 93-132):
- `loadAlbums()` - Service call in view
- `loadFavoritesCount()` - Business logic in view
- `createFavoritesAlbum()` - Data transformation in view

**PeopleGridView.swift** (lines 47-78):
- `loadPeople()` - Service call with error handling in view

**SearchView.swift** (lines 145-175):
- `performSearch()` - Search logic with debouncing in view

**StatsView.swift** (lines 242-276):
- `loadStatsIfNeeded()` - Caching and loading logic in view
- `refreshStats()` - Service call in view

**SignInView.swift** (lines 417-511):
- `signIn()` - Complex authentication logic in view
- URL validation and cleanup in view

**SlideshowView.swift** (lines 333-693):
- Extensive business logic for slideshow management
- Image queue management
- Asset loading logic
- Animation state management

**Impact**: 
- Views are difficult to test
- Business logic scattered across UI layer
- Hard to reuse logic
- Violates single responsibility principle

**Solution**: Move all business logic to ViewModels.

---

### 3. Missing ViewModels for Major Views
**Issue**: Several major views don't have ViewModels, while some do (inconsistent pattern).

**Views WITHOUT ViewModels**:
- `AssetGridView` - Complex view with pagination, deep linking, slideshow
- `AlbumListView` - Album loading and favorites logic
- `PeopleGridView` - People loading logic
- `TagsGridView` - Tags loading logic
- `FoldersView` - Folders loading logic
- `SearchView` - Search functionality
- `StatsView` - Statistics loading
- `SignInView` - Authentication logic
- `FullScreenImageView` - Image loading and navigation
- `VideoPlayerView` - Video playback logic
- `SlideshowView` - Complex slideshow logic

**Views WITH ViewModels** (Good examples):
- `ExploreView` - Has `ExploreViewModel`
- `WorldMapView` - Has `WorldMapViewModel`
- `ContinentDetailView` - Has `ContinentViewModel`
- `CountryDetailView` - Has `CountryViewModel`

**Impact**: 
- Inconsistent architecture
- Some views follow MVVM, others don't
- Makes codebase harder to understand and maintain

**Solution**: Create ViewModels for all views that interact with services.

---

## 🟡 MEDIUM PRIORITY - Architectural Issues

### 4. Services Created Internally in Views
**Issue**: `SlideshowView` creates its own service instances instead of receiving them via dependency injection.

**Location**: `SlideshowView.swift` (lines 35-39)
```swift
// Create services internally
let userManager = UserManager()
let networkService = NetworkService(userManager: userManager)
self.assetService = AssetService(networkService: networkService)
self.albumService = AlbumService(networkService: networkService)
```

**Impact**:
- Violates dependency injection principle
- Creates new service instances (potential memory/state issues)
- Hard to test (can't inject mocks)
- Services may not share state with rest of app

**Solution**: Inject services through initializer, or better yet, create a `SlideshowViewModel` that receives services.

---

### 5. Views with Too Many Responsibilities
**Issue**: Some views handle multiple concerns (UI, state, business logic, navigation).

**Examples**:
- `AssetGridView` - UI rendering, pagination, deep linking, slideshow triggering, focus management
- `SlideshowView` - UI rendering, image queue management, asset loading, animation state, timer management
- `FullScreenImageView` - Image loading, video playback, navigation, EXIF display

**Impact**:
- Views become large and complex
- Hard to maintain and test
- Violates single responsibility principle

**Solution**: Extract responsibilities into ViewModels and helper classes.

---

### 6. Inconsistent State Management
**Issue**: Mix of `@State`, `@StateObject`, `@ObservedObject` without clear pattern.

**Examples**:
- Some views use `@State` for loading/error states
- Some views use `@ObservedObject` for services
- Some views use `@StateObject` for ViewModels (when they exist)
- Inconsistent error handling patterns

**Impact**:
- Unclear ownership of state
- Potential memory leaks or unnecessary re-renders
- Hard to reason about state lifecycle

**Solution**: 
- Use `@StateObject` for ViewModels (owned by view)
- Use `@ObservedObject` for services only when necessary
- Use `@State` only for local UI state
- Standardize error handling in ViewModels

---

### 7. Direct Service Observation in Views
**Issue**: Views observe services directly with `@ObservedObject` instead of observing ViewModels.

**Current Pattern**:
```swift
@ObservedObject var assetService: AssetService
@ObservedObject var authService: AuthenticationService
```

**Better Pattern**:
```swift
@StateObject var viewModel: AssetGridViewModel
// ViewModel observes services internally
```

**Impact**:
- Views depend on service implementation details
- Changes to services directly affect views
- Harder to test (need to mock services in views)

**Solution**: Views should only observe ViewModels, not services directly.

---

## 🟢 LOW PRIORITY - Code Quality Improvements

### 8. Inconsistent Error Handling
**Issue**: Error handling patterns vary across views.

**Examples**:
- Some use `errorMessage: String?`
- Some use `error: Error?`
- Some show alerts, others show inline messages
- Error messages sometimes come from services, sometimes from views

**Solution**: Standardize error handling in ViewModels with consistent error types and presentation.

---

### 9. Business Logic in Computed Properties
**Issue**: Some computed properties contain business logic.

**Examples**:
- `AlbumListView.createFavoritesAlbum()` - Creates business objects
- `AssetGridView.getEmptyStateTitle()` - Conditional logic for UI text

**Solution**: Move business logic to ViewModels, keep computed properties for simple transformations.

---

### 10. NotificationCenter Usage for Cross-View Communication
**Issue**: Using NotificationCenter for view coordination instead of proper state management.

**Examples**:
- `NotificationNames.startAutoSlideshow`
- `NotificationNames.refreshAllTabs`
- `NotificationNames.stopAutoSlideshowTimer`

**Impact**:
- Hard to trace data flow
- Potential memory leaks if observers not removed
- Difficult to test

**Solution**: Use proper state management (ViewModels, shared state objects, or environment objects).

---

### 11. Direct UserDefaults Access in Views
**Issue**: Views directly access UserDefaults instead of through ViewModels or settings service.

**Examples**:
- `SlideshowView` - Multiple `UserDefaults.standard` accesses
- `AssetGridView` - UserDefaults for slideshow settings

**Solution**: Access UserDefaults through ViewModels or a settings service.

---

### 12. Code Duplication
**Issue**: Similar patterns repeated across views (loading, error handling, service calls).

**Examples**:
- Loading state management repeated in every view
- Error handling patterns duplicated
- Service call patterns similar across views

**Solution**: Create base ViewModel class or protocol with common functionality.

---

## 📊 Summary Statistics

- **Views with ViewModels**: 4 (ExploreView, WorldMapView, ContinentDetailView, CountryDetailView)
- **Views without ViewModels**: 11+ (AssetGridView, AlbumListView, PeopleGridView, TagsGridView, FoldersView, SearchView, StatsView, SignInView, FullScreenImageView, VideoPlayerView, SlideshowView)
- **Views directly accessing services**: 11+
- **Views with business logic**: 11+

## 🎯 Recommended Refactoring Order

1. **Start with high-traffic views**: `AssetGridView`, `SearchView`
2. **Then complex views**: `SlideshowView`, `FullScreenImageView`
3. **Then simpler views**: `PeopleGridView`, `TagsGridView`, `FoldersView`
4. **Finally**: `StatsView`, `SignInView`

## 📝 Notes

- The codebase already has good examples of MVVM (ExploreViewModel, WorldMapViewModel)
- Services are well-structured and can be easily injected into ViewModels
- The main work is extracting business logic from views into ViewModels
- Consider creating a base `ViewModel` protocol or class for common functionality

