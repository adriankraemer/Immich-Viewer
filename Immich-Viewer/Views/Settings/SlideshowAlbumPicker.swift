import SwiftUI

// MARK: - Slideshow Album Picker

/// A full-screen album picker for selecting a slideshow album
/// Displays albums in a grid with search functionality
struct SlideshowAlbumPicker: View {
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Services
    let albumService: AlbumService
    let assetService: AssetService
    let authService: AuthenticationService
    
    // MARK: - Bindings
    @Binding var selectedAlbumId: String
    @Binding var selectedAlbumName: String
    
    // MARK: - State
    @State private var albums: [ImmichAlbum] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    @FocusState private var focusedItemId: String?
    
    // MARK: - Computed Properties
    
    private var filteredAlbums: [ImmichAlbum] {
        if searchText.isEmpty {
            return albums
        }
        return albums.filter { $0.albumName.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var thumbnailProvider: AlbumThumbnailProvider {
        AlbumThumbnailProvider(albumService: albumService, assetService: assetService)
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            SharedGradientBackground()
            
            VStack(spacing: 0) {
                // Custom header with title
                HStack {
                    Text(String(localized: "Select Slideshow Album"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 40)
                .padding(.top, 40)
                .padding(.bottom, 20)
                
                if isLoading {
                    Spacer()
                    CinematicLoadingView(message: String(localized: "Loading albums..."))
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    errorView(message: error)
                    Spacer()
                } else {
                    albumGridContent
                }
            }
        }
        .onAppear {
            loadAlbums()
        }
        .onExitCommand {
            dismiss()
        }
    }
    
    // MARK: - Album Grid Content
    
    private var albumGridContent: some View {
        VStack(spacing: 20) {
            // Search bar
            searchBar
            
            // Album grid
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 40) {
                    // "All Photos" option (clears selection)
                    allPhotosOption
                    
                    // Album items
                    ForEach(filteredAlbums) { album in
                        albumButton(for: album)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(PickerTheme.textSecondary)
            
            TextField(String(localized: "Search albums..."), text: $searchText)
                .textFieldStyle(.plain)
                .foregroundColor(PickerTheme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(PickerTheme.surface.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal, 40)
        .padding(.top, 20)
    }
    
    // MARK: - Grid Columns
    
    private var gridColumns: [GridItem] {
        [
            GridItem(.fixed(400), spacing: 30),
            GridItem(.fixed(400), spacing: 30),
            GridItem(.fixed(400), spacing: 30),
            GridItem(.fixed(400), spacing: 30)
        ]
    }
    
    // MARK: - All Photos Option
    
    private var allPhotosOption: some View {
        let isSelected = selectedAlbumId.isEmpty
        
        return Button(action: {
            selectedAlbumId = ""
            selectedAlbumName = ""
            dismiss()
        }) {
            VStack(spacing: 0) {
                // Icon section
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    PickerTheme.accent.opacity(0.3),
                                    PickerTheme.accent.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 380, height: 220)
                    
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(PickerTheme.accent.opacity(0.2))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundColor(PickerTheme.accent)
                        }
                        
                        Text(String(localized: "All Photos"))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(PickerTheme.textPrimary)
                    }
                }
                
                // Label section
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(String(localized: "All Photos"))
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(focusedItemId == "all_photos" ? PickerTheme.textPrimary : PickerTheme.textSecondary)
                        
                        Spacer()
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(PickerTheme.success)
                        }
                    }
                    
                    Text(String(localized: "Default - Random from all photos"))
                        .font(.subheadline)
                        .foregroundColor(PickerTheme.textTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(width: 380, height: 80)
                .background(Color.black.opacity(0.7))
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isSelected ? PickerTheme.success : (focusedItemId == "all_photos" ? PickerTheme.accent : Color.white.opacity(0.1)),
                        lineWidth: isSelected || focusedItemId == "all_photos" ? 2.5 : 1
                    )
            )
        }
        .buttonStyle(CardButtonStyle())
        .focused($focusedItemId, equals: "all_photos")
    }
    
    // MARK: - Album Button
    
    private func albumButton(for album: ImmichAlbum) -> some View {
        let isSelected = selectedAlbumId == album.id
        let isFocused = focusedItemId == album.id
        
        return Button(action: {
            selectedAlbumId = album.id
            selectedAlbumName = album.albumName
            dismiss()
        }) {
            VStack(spacing: 0) {
                // Thumbnail section
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(PickerTheme.surface.opacity(0.6))
                        .frame(width: 380, height: 220)
                    
                    AlbumPickerThumbnail(
                        album: album,
                        thumbnailProvider: thumbnailProvider
                    )
                    .frame(width: 380, height: 220)
                    .cornerRadius(16)
                }
                
                // Info section
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(album.albumName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(isFocused ? PickerTheme.textPrimary : PickerTheme.textSecondary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(PickerTheme.success)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "photo.stack")
                            .font(.caption2)
                        Text("\(album.assetCount)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(PickerTheme.accent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(width: 380, height: 80)
                .background(Color.black.opacity(0.7))
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isSelected ? PickerTheme.success : (isFocused ? PickerTheme.accent : Color.white.opacity(0.1)),
                        lineWidth: isSelected || isFocused ? 2.5 : 1
                    )
            )
        }
        .buttonStyle(CardButtonStyle())
        .focused($focusedItemId, equals: album.id)
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(PickerTheme.surface)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.orange, Color.red],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            VStack(spacing: 12) {
                Text(String(localized: "Failed to load albums"))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(PickerTheme.textPrimary)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(PickerTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }
            
            Button(action: { loadAlbums() }) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.clockwise")
                    Text(String(localized: "Try Again"))
                }
                .font(.headline)
                .foregroundColor(.black)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(PickerTheme.accent)
                .cornerRadius(12)
            }
            .buttonStyle(CardButtonStyle())
        }
        .padding(40)
    }
    
    // MARK: - Load Albums
    
    private func loadAlbums() {
        guard authService.isAuthenticated else {
            errorMessage = "Not authenticated"
            isLoading = false
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedAlbums = try await albumService.fetchAlbums()
                await MainActor.run {
                    self.albums = fetchedAlbums.sorted { $0.albumName.localizedCaseInsensitiveCompare($1.albumName) == .orderedAscending }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Album Picker Thumbnail

private struct AlbumPickerThumbnail: View {
    let album: ImmichAlbum
    let thumbnailProvider: AlbumThumbnailProvider
    
    @State private var thumbnail: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if isLoading {
                SkeletonLoadingView()
            } else if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
                
                // Subtle gradient overlay
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.3)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                // Fallback icon
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(PickerTheme.accent.opacity(0.2))
                            .frame(width: 70, height: 70)
                        
                        Image(systemName: "photo.stack")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundColor(PickerTheme.textSecondary)
                    }
                }
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        Task {
            let thumbnails = await thumbnailProvider.loadThumbnails(for: album)
            await MainActor.run {
                self.thumbnail = thumbnails.first
                self.isLoading = false
            }
        }
    }
}

// MARK: - Picker Theme

private enum PickerTheme {
    static let accent = Color(red: 245/255, green: 166/255, blue: 35/255)
    static let success = Color.green
    static let surface = Color(red: 30/255, green: 30/255, blue: 32/255)
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 142/255, green: 142/255, blue: 147/255)
    static let textTertiary = Color(red: 99/255, green: 99/255, blue: 102/255)
}
