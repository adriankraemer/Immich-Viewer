# Immich-AppleTV

A native Apple TV app for browsing your self-hosted Immich photo library.

## Beta Testing

Join the beta test on TestFlight: [https://testflight.apple.com/join/7nGMT7cz](https://testflight.apple.com/join/7nGMT7cz)

## Features

### Photo Browsing
- **Photos Tab**: Browse all your photos and videos in a beautiful grid layout
- **Albums**: View personal and shared albums with cover images
- **People**: Browse photos by recognized faces using Immich's face recognition
- **Tags**: Organize and browse photos by tags
- **Folders**: Navigate your photo library by folder structure

### Discovery & Exploration
- **Explore**: Discover library statistics, city-based photo groupings, and highlights
- **World Map**: Interactive map view showing photo locations around the world
- **Search**: Full-text search across assets and albums with faceted results

### Slideshow
- **Ken Burns Effect**: Cinematic pan and zoom animations
- **Auto-Slideshow**: Automatic slideshow after inactivity timeout
- **Shuffle Mode**: Randomize photo order
- **Customizable Intervals**: Adjust slideshow timing to your preference
- **Background Color**: Customize slideshow background
- **Reflections**: Optional reflection effects for photos

### Media Features
- **Full-Screen Viewing**: High-quality image and video playback
- **EXIF Information**: View detailed photo metadata overlay
- **RAW Support**: Automatic conversion of RAW images to preview format
- **Video Playback**: Native video player for video assets
- **Thumbnail Animations**: Optional animated thumbnail previews

### User Experience
- **Multiple Account Support**: Switch between multiple Immich accounts
- **Authentication Options**: Sign in with email/password or API key
- **Top Shelf Integration**: Display recent or random photos on Apple TV home screen
- **Deep Linking**: Open specific photos via URL scheme (`immichgallery://asset/{id}`)
- **Customizable Navigation**: Choose between tab bar or sidebar navigation style
- **Configurable Tabs**: Show/hide Albums, Tags, and Folders tabs
- **Default Startup Tab**: Set which tab opens when the app launches
- **24-Hour Clock**: Optional 24-hour time format

### Settings & Customization
- **User Management**: Add, switch, and remove user accounts
- **Display Preferences**: Hide image overlays, adjust slideshow settings
- **Top Shelf Configuration**: Choose carousel or sectioned style, recent or random photos
- **Sort Options**: Customize photo sorting order

## Requirements

- Apple TV (4th generation or later)
- tvOS 15.0 or later
- An Immich server accessible on your network

## Getting Started

1. Launch the app on your Apple TV
2. Sign in with your Immich server URL
3. Enter your credentials (email/password or API key)
4. Start browsing your photos

## Architecture

This app follows a service-oriented architecture with clear separation between:
- **Presentation Layer**: SwiftUI views and view models
- **Business Logic Layer**: Service classes for API interactions
- **Data Layer**: Storage abstractions (UserDefaults + Keychain)
- **Infrastructure Layer**: Network, caching, and persistence

For detailed architecture documentation, see [ARCHITECTURE.md](ARCHITECTURE.md).

## License

GPL-3.0. See [LICENSE](LICENSE) for details.

## Acknowledgments

Built for [Immich](https://immich.app). Forked from [mensadilabs/Immich-Gallery](https://github.com/mensadilabs/Immich-Gallery).
