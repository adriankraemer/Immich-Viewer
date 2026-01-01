# Test Suite Documentation

This directory contains comprehensive test cases for the Immich-AppleTV application.

## Test Files

### MockUserStorage.swift
Mock implementation of the `UserStorage` protocol for testing. Provides in-memory storage for users and tokens, allowing tests to run without affecting real storage.

### UserManagerTests.swift
Tests for the `UserManager` class, covering:
- Initialization with empty users
- Saving and loading users
- Finding users by email and server URL
- User existence checks
- Switching between users
- Removing users
- Clearing all users
- Getting users for specific servers
- Current user properties
- Logout functionality

### AuthenticationServiceTests.swift
Tests for the `AuthenticationService` class, covering:
- Initialization with unauthenticated state
- Getting authentication headers for JWT tokens
- Getting authentication headers for API keys
- Handling missing tokens
- Base URL and access token access
- Clearing credentials
- Updating credentials from current user

### NetworkServiceTests.swift
Tests for the `NetworkService` class, covering:
- Initialization with empty credentials
- Clearing credentials
- Updating credentials from current user
- ImmichError error handling and shouldLogout logic
- Error descriptions

### HybridUserStorageTests.swift
Tests for the `HybridUserStorage` class, covering:
- Saving and loading users
- Saving and retrieving tokens
- Removing users and associated tokens
- Handling multiple users
- Removing all user data
- Token removal separately
- Handling non-existent tokens

### AssetServiceTests.swift
Tests for the `AssetService` class and related models, covering:
- Service initialization
- RAW image format detection
- Non-RAW image format handling
- Video asset handling
- ImmichAsset equality comparison

## Running Tests

### In Xcode
1. Open the project in Xcode
2. Press `Cmd+U` to run all tests
3. Or use the Test Navigator (Cmd+6) to run individual test suites

### From Command Line
```bash
xcodebuild test -scheme Immich-AppleTV -destination 'platform=tvOS Simulator,name=Apple TV'
```

## Test Coverage

The test suite focuses on the most critical components:
1. **User Management** - Core functionality for multi-user support
2. **Authentication** - Security-critical authentication flows
3. **Network Layer** - HTTP request handling and error management
4. **Storage** - Data persistence and retrieval
5. **Asset Management** - Photo and video handling

## Future Test Additions

Consider adding tests for:
- ViewModels (ExploreViewModel, WorldMapViewModel, etc.)
- Additional services (AlbumService, PeopleService, TagService)
- UI components (if using UI testing)
- Integration tests for end-to-end flows
- Performance tests for large datasets

