import SwiftUI

// MARK: - Cinematic Theme Constants

private enum CinematicTheme {
    static let accent = Color(red: 245/255, green: 166/255, blue: 35/255)
    static let accentLight = Color(red: 255/255, green: 200/255, blue: 100/255)
    static let surface = Color(red: 30/255, green: 30/255, blue: 32/255)
    static let surfaceLight = Color(red: 45/255, green: 45/255, blue: 48/255)
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 142/255, green: 142/255, blue: 147/255)
    static let textTertiary = Color(red: 99/255, green: 99/255, blue: 102/255)
}

// MARK: - Thumbnail Provider Protocol

/// Protocol for loading thumbnails for grid items
/// Different implementations handle different item types (albums, people, tags, etc.)
protocol ThumbnailProvider {
    func loadThumbnails(for item: any GridDisplayable) async -> [UIImage]
}

// MARK: - Main Grid View

/// Reusable grid view component for displaying albums, people, tags, folders, etc.
/// Handles loading states, errors, empty states, and focus management
struct SharedGridView<Item: GridDisplayable>: View {
    let items: [Item]
    let config: GridConfig
    let thumbnailProvider: ThumbnailProvider
    let isLoading: Bool
    let errorMessage: String?
    let onItemSelected: (Item) -> Void
    let onRetry: () -> Void
    
    @FocusState private var focusedItemId: String?
    
    var body: some View {
        ZStack {
            SharedGradientBackground()
            
            if isLoading {
                // Cinematic loading state
                CinematicLoadingView(message: config.loadingText)
            } else if let errorMessage = errorMessage {
                // Cinematic error state
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(CinematicTheme.surface)
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
                        Text("Something went wrong")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(CinematicTheme.textPrimary)
                        
                        Text(errorMessage)
                            .font(.body)
                            .foregroundColor(CinematicTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 500)
                    }
                    
                    Button(action: { onRetry() }) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.clockwise")
                            Text("Try Again")
                        }
                        .font(.headline)
                        .foregroundColor(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(CinematicTheme.accent)
                        .cornerRadius(12)
                    }
                    .buttonStyle(CardButtonStyle())
                }
                .padding(40)
            } else if items.isEmpty {
                // Cinematic empty state
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(CinematicTheme.surface)
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: config.emptyStateText.contains("Album") ? "folder" : config.emptyStateText.contains("People") ? "person.crop.circle" : "tag")
                            .font(.system(size: 50))
                            .foregroundColor(CinematicTheme.textTertiary)
                    }
                    
                    VStack(spacing: 12) {
                        Text(config.emptyStateText)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(CinematicTheme.textPrimary)
                        
                        Text(config.emptyStateDescription)
                            .font(.body)
                            .foregroundColor(CinematicTheme.textSecondary)
                    }
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: config.columns, spacing: config.spacing) {
                        ForEach(items) { item in
                            Button(action: {
                                onItemSelected(item)
                            }) {
                                SharedGridItemView(
                                    item: item,
                                    config: config,
                                    thumbnailProvider: thumbnailProvider,
                                    isFocused: focusedItemId == item.id
                                )
                            }
                            .frame(width: config.itemWidth, height: config.itemHeight)
                            .focused($focusedItemId, equals: item.id)
                            .animation(.easeInOut(duration: 0.2), value: focusedItemId)
                            .padding(10)
                            .buttonStyle(CardButtonStyle())
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Skeleton Loading View
struct SkeletonLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            CinematicTheme.surface.opacity(0.5)
            
            // Shimmer effect
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.white.opacity(0.08),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .offset(x: isAnimating ? 400 : -400)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Cinematic Loading View
struct CinematicLoadingView: View {
    var message: String = "Loading..."
    @State private var rotation: Double = 0
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(CinematicTheme.surface, lineWidth: 4)
                    .frame(width: 70, height: 70)
                
                // Animated gradient ring
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        AngularGradient(
                            colors: [CinematicTheme.accent, CinematicTheme.accentLight, CinematicTheme.accent],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(rotation))
            }
            
            Text(message)
                .font(.headline)
                .foregroundColor(CinematicTheme.textSecondary)
        }
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Grid Item View
struct SharedGridItemView<Item: GridDisplayable>: View {
    let item: Item
    let config: GridConfig
    let thumbnailProvider: ThumbnailProvider
    let isFocused: Bool
    
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    @State private var thumbnail: UIImage?
    @State private var isLoadingThumbnails = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Thumbnail section with cinematic styling
            ZStack {
                // Glass background
                RoundedRectangle(cornerRadius: 16)
                    .fill(CinematicTheme.surface.opacity(0.6))
                    .frame(width: config.itemWidth - 20, height: 280)
                
                if isLoadingThumbnails {
                    // Skeleton loading
                    SkeletonLoadingView()
                        .frame(width: config.itemWidth - 20, height: 280)
                        .cornerRadius(16)
                } else if let thumbnail = thumbnail {
                    // Thumbnail with cinematic overlay
                    ZStack {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: config.itemWidth - 20, height: 280)
                            .clipped()
                            .cornerRadius(16)
                        
                        // Subtle gradient overlay for depth
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.black.opacity(0.3)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .cornerRadius(16)
                    }
                } else {
                    // Fallback content with cinematic styling
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            (item.gridColor ?? CinematicTheme.accent).opacity(0.3),
                                            (item.gridColor ?? CinematicTheme.accent).opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 90, height: 90)
                            
                            Image(systemName: item.iconName)
                                .font(.system(size: 40, weight: .medium))
                                .foregroundColor(item.gridColor ?? CinematicTheme.textSecondary)
                        }
                        
                        Text(item.primaryTitle)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(CinematicTheme.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            
            // Info section with glassmorphism
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            // Special icons for different types
                            if item.id.hasPrefix("smart_") {
                                Image(systemName: "heart.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            }
                            
                            Text(item.primaryTitle)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(isFocused ? CinematicTheme.textPrimary : CinematicTheme.textSecondary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            // Favorite indicator with glow
                            if let isFavorite = item.isFavorite, isFavorite {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.red)
                                    .shadow(color: .red.opacity(0.5), radius: 4, x: 0, y: 0)
                            }
                            
                            // Shared indicator
                            if let isShared = item.isShared, isShared, let sharingText = item.sharingText {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.2.fill")
                                        .font(.caption)
                                        .foregroundColor(CinematicTheme.accent)
                                    Text(sharingText)
                                        .font(.caption)
                                        .foregroundColor(CinematicTheme.accent)
                                }
                            }
                        }
                        
                        // Secondary title or description
                        if let secondaryTitle = item.secondaryTitle {
                            Text(secondaryTitle)
                                .font(.subheadline)
                                .foregroundColor(CinematicTheme.textTertiary)
                                .lineLimit(2)
                        } else if let description = item.description {
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(CinematicTheme.textTertiary)
                                .lineLimit(2)
                        }
                        
                        // Bottom info row with accent color
                        HStack(spacing: 12) {
                            if let itemCount = item.itemCount {
                                HStack(spacing: 4) {
                                    Image(systemName: "photo.stack")
                                        .font(.caption2)
                                    Text("\(itemCount)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(CinematicTheme.accent)
                            }
                            
                            if let createdAt = item.gridCreatedAt, let formattedDate = formatDate(createdAt) {
                                Text(formattedDate)
                                    .font(.caption)
                                    .foregroundColor(CinematicTheme.textTertiary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, config.itemHeight > 360 ? 50 : 18)
            }
            .frame(width: config.itemWidth - 20, height: config.itemHeight > 360 ? 160 : 120)
            .background(
                // Glassmorphism info panel
                ZStack {
                    Color.black.opacity(0.7)
                    
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            )
        }
        // Cinematic card styling
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            isFocused ? CinematicTheme.accent.opacity(0.8) : Color.white.opacity(0.1),
                            isFocused ? CinematicTheme.accent.opacity(0.3) : Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isFocused ? 2.5 : 1
                )
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isFocused ? CinematicTheme.surfaceLight.opacity(0.3) : CinematicTheme.surface.opacity(0.3))
        )
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        guard !isLoadingThumbnails else { return }
        isLoadingThumbnails = true
        
        Task {
            let loadedThumbnails = await thumbnailProvider.loadThumbnails(for: item)
            await MainActor.run {
                self.thumbnail = loadedThumbnails.first
                self.isLoadingThumbnails = false
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        
        // Try alternative format
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        
        return nil
    }
}
