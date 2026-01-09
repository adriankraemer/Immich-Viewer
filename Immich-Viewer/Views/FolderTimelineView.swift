import SwiftUI

// MARK: - Cinematic Theme Constants
private enum TimelineTheme {
    static let accent = Color(red: 245/255, green: 166/255, blue: 35/255)
    static let surface = Color(red: 30/255, green: 30/255, blue: 32/255)
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 142/255, green: 142/255, blue: 147/255)
    static let folderColor = Color(red: 100/255, green: 149/255, blue: 237/255)
}

/// Timeline view for folders grouped by their most recent asset date
struct FolderTimelineView: View {
    let timelineGroups: [FolderTimelineGroup]
    let isLoading: Bool
    let onFolderSelected: (ImmichFolder) -> Void
    
    @FocusState private var focusedPath: String?
    
    var body: some View {
        if isLoading {
            loadingView
        } else if timelineGroups.isEmpty {
            emptyView
        } else {
            timelineContent
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(TimelineTheme.accent)
            
            Text(LocalizedStringResource("Loading folder dates..."))
                .font(.headline)
                .foregroundColor(TimelineTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundColor(TimelineTheme.textSecondary)
            
            Text(LocalizedStringResource("No Timeline Data"))
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(TimelineTheme.textPrimary)
            
            Text(LocalizedStringResource("Folder dates could not be determined"))
                .font(.body)
                .foregroundColor(TimelineTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var timelineContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 40) {
                ForEach(timelineGroups) { group in
                    TimelineGroupSection(
                        group: group,
                        focusedPath: $focusedPath,
                        onFolderSelected: onFolderSelected
                    )
                }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
        }
    }
}

/// A section in the timeline representing a time period
struct TimelineGroupSection: View {
    let group: FolderTimelineGroup
    var focusedPath: FocusState<String?>.Binding
    let onFolderSelected: (ImmichFolder) -> Void
    
    // Grid layout for folders within a section
    private let columns = [
        GridItem(.fixed(450), spacing: 30),
        GridItem(.fixed(450), spacing: 30),
        GridItem(.fixed(450), spacing: 30)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Section header
            sectionHeader
            
            // Folder grid
            LazyVGrid(columns: columns, spacing: 30) {
                ForEach(group.folders, id: \.path) { folder in
                    TimelineFolderCard(
                        folder: folder,
                        isFocused: focusedPath.wrappedValue == folder.path,
                        onSelect: { onFolderSelected(folder) }
                    )
                    .focused(focusedPath, equals: folder.path)
                }
            }
        }
    }
    
    private var sectionHeader: some View {
        HStack(spacing: 16) {
            // Accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(TimelineTheme.accent)
                .frame(width: 4, height: 36)
            
            // Date icon
            Image(systemName: "calendar")
                .font(.system(size: 24))
                .foregroundColor(TimelineTheme.accent)
            
            // Title and count
            VStack(alignment: .leading, spacing: 4) {
                Text(group.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(TimelineTheme.textPrimary)
                
                Text("\(group.folders.count) \(String(localized: "folder"))\(group.folders.count == 1 ? "" : "s")")
                    .font(.system(size: 16))
                    .foregroundColor(TimelineTheme.textSecondary)
            }
            
            Spacer()
        }
        .padding(.bottom, 8)
    }
}

/// A folder card for the timeline view
struct TimelineFolderCard: View {
    let folder: ImmichFolder
    let isFocused: Bool
    let onSelect: () -> Void
    
    private var formattedDate: String? {
        guard let date = folder.mostRecentAssetDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 16) {
                // Folder icon header
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(TimelineTheme.folderColor.opacity(isFocused ? 0.3 : 0.15))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "folder.fill")
                            .font(.system(size: 28))
                            .foregroundColor(TimelineTheme.folderColor)
                    }
                    
                    Spacer()
                    
                    // Date badge
                    if let date = formattedDate {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 14))
                            Text(date)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(isFocused ? TimelineTheme.accent : TimelineTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(TimelineTheme.surface.opacity(0.6))
                        )
                    }
                }
                
                // Folder name
                Text(folder.primaryTitle)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(TimelineTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Path
                Text(folder.path)
                    .font(.system(size: 14))
                    .foregroundColor(TimelineTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer(minLength: 0)
                
                // Asset count if available
                if let count = folder.assetCount {
                    HStack {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 14))
                        Text("\(count) \(String(localized: "items"))")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(TimelineTheme.textSecondary)
                }
            }
            .padding(24)
            .frame(width: 450, height: 220)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(TimelineTheme.surface.opacity(isFocused ? 0.9 : 0.6))
                    
                    // Subtle gradient overlay
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.05),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Border
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            isFocused ? TimelineTheme.accent.opacity(0.6) : Color.white.opacity(0.1),
                            lineWidth: isFocused ? 2 : 1
                        )
                }
            )
        }
        .buttonStyle(TimelineCardButtonStyle())
    }
}

/// Button style for timeline cards
struct TimelineCardButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : (isFocused ? 1.05 : 1.0))
            .shadow(
                color: isFocused ? TimelineTheme.accent.opacity(0.3) : Color.black.opacity(0.3),
                radius: isFocused ? 20 : 10,
                x: 0,
                y: isFocused ? 10 : 5
            )
            .animation(.easeOut(duration: 0.2), value: isFocused)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    let sampleGroups = [
        FolderTimelineGroup(
            title: "January 2024",
            folders: [
                ImmichFolder(path: "/photos/vacation", mostRecentAssetDate: Date()),
                ImmichFolder(path: "/photos/birthday", mostRecentAssetDate: Date().addingTimeInterval(-86400))
            ],
            startDate: Date()
        ),
        FolderTimelineGroup(
            title: "December 2023",
            folders: [
                ImmichFolder(path: "/photos/christmas", mostRecentAssetDate: Date().addingTimeInterval(-2592000))
            ],
            startDate: Date().addingTimeInterval(-2592000)
        )
    ]
    
    return ZStack {
        SharedGradientBackground()
        FolderTimelineView(
            timelineGroups: sampleGroups,
            isLoading: false
        ) { folder in
            print("Selected: \(folder.path)")
        }
    }
}

