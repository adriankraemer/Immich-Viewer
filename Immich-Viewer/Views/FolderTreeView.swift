import SwiftUI

// MARK: - Cinematic Theme Constants
private enum TreeTheme {
    static let accent = Color(red: 245/255, green: 166/255, blue: 35/255)
    static let surface = Color(red: 30/255, green: 30/255, blue: 32/255)
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 142/255, green: 142/255, blue: 147/255)
    static let folderColor = Color(red: 100/255, green: 149/255, blue: 237/255) // Cornflower blue
}

/// A hierarchical tree view for displaying folders with expandable/collapsible nodes
struct FolderTreeView: View {
    let folders: [ImmichFolder]
    let onFolderSelected: (ImmichFolder) -> Void
    
    @State private var expandedPaths: Set<String> = []
    @FocusState private var focusedPath: String?
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(folders, id: \.path) { folder in
                    FolderTreeNode(
                        folder: folder,
                        level: 0,
                        expandedPaths: $expandedPaths,
                        focusedPath: $focusedPath,
                        onSelect: onFolderSelected
                    )
                }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
        }
    }
}

/// A single node in the folder tree (recursive component)
struct FolderTreeNode: View {
    let folder: ImmichFolder
    let level: Int
    @Binding var expandedPaths: Set<String>
    var focusedPath: FocusState<String?>.Binding
    let onSelect: (ImmichFolder) -> Void
    
    private var isExpanded: Bool {
        expandedPaths.contains(folder.path)
    }
    
    private var hasChildren: Bool {
        folder.hasChildren
    }
    
    private var indentation: CGFloat {
        CGFloat(level) * 40
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Main folder row
            Button(action: {
                if hasChildren {
                    // Toggle expansion
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isExpanded {
                            expandedPaths.remove(folder.path)
                        } else {
                            expandedPaths.insert(folder.path)
                        }
                    }
                } else {
                    // Select folder (leaf node)
                    onSelect(folder)
                }
            }) {
                FolderRowContent(
                    folder: folder,
                    isExpanded: isExpanded,
                    hasChildren: hasChildren,
                    isFocused: focusedPath.wrappedValue == folder.path
                )
            }
            .buttonStyle(TreeNodeButtonStyle())
            .focused(focusedPath, equals: folder.path)
            .padding(.leading, indentation)
            .contextMenu {
                Button("Open Folder") {
                    onSelect(folder)
                }
                if hasChildren {
                    Button(isExpanded ? "Collapse" : "Expand") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isExpanded {
                                expandedPaths.remove(folder.path)
                            } else {
                                expandedPaths.insert(folder.path)
                            }
                        }
                    }
                }
            }
            
            // Children (if expanded)
            if isExpanded, let children = folder.children {
                ForEach(children, id: \.path) { child in
                    FolderTreeNode(
                        folder: child,
                        level: level + 1,
                        expandedPaths: $expandedPaths,
                        focusedPath: focusedPath,
                        onSelect: onSelect
                    )
                }
            }
        }
    }
}

/// Content view for a folder row
struct FolderRowContent: View {
    let folder: ImmichFolder
    let isExpanded: Bool
    let hasChildren: Bool
    let isFocused: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Expansion indicator
            if hasChildren {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isFocused ? TreeTheme.accent : TreeTheme.textSecondary)
                    .frame(width: 24)
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
            } else {
                // Spacer for alignment
                Color.clear
                    .frame(width: 24)
            }
            
            // Folder icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(TreeTheme.folderColor.opacity(isFocused ? 0.3 : 0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: hasChildren ? "folder.fill" : "folder")
                    .font(.system(size: 22))
                    .foregroundColor(TreeTheme.folderColor)
            }
            
            // Folder name and path
            VStack(alignment: .leading, spacing: 4) {
                Text(folder.primaryTitle)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(isFocused ? TreeTheme.textPrimary : TreeTheme.textPrimary.opacity(0.9))
                    .lineLimit(1)
                
                if let count = folder.assetCount {
                    Text("\(count) items")
                        .font(.system(size: 16))
                        .foregroundColor(TreeTheme.textSecondary)
                } else if hasChildren {
                    Text("\(folder.children?.count ?? 0) subfolders")
                        .font(.system(size: 16))
                        .foregroundColor(TreeTheme.textSecondary)
                }
            }
            
            Spacer()
            
            // Open folder button (for folders with children)
            if hasChildren {
                Button(action: {
                    // This opens the folder contents
                }) {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 24))
                        .foregroundColor(isFocused ? TreeTheme.accent : TreeTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .opacity(isFocused ? 1 : 0.5)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isFocused ? TreeTheme.surface.opacity(0.8) : TreeTheme.surface.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isFocused ? TreeTheme.accent.opacity(0.6) : Color.clear,
                    lineWidth: 2
                )
        )
    }
}

/// Button style for tree nodes with focus support
struct TreeNodeButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : (isFocused ? 1.02 : 1.0))
            .shadow(
                color: isFocused ? TreeTheme.accent.opacity(0.2) : Color.clear,
                radius: isFocused ? 10 : 0,
                x: 0,
                y: isFocused ? 4 : 0
            )
            .animation(.easeOut(duration: 0.15), value: isFocused)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    let sampleFolders = [
        ImmichFolder(
            path: "/photos",
            children: [
                ImmichFolder(
                    path: "/photos/2024",
                    children: [
                        ImmichFolder(path: "/photos/2024/vacation"),
                        ImmichFolder(path: "/photos/2024/birthday")
                    ]
                ),
                ImmichFolder(path: "/photos/2023")
            ]
        ),
        ImmichFolder(path: "/documents")
    ]
    
    return ZStack {
        SharedGradientBackground()
        FolderTreeView(folders: sampleFolders) { folder in
            print("Selected: \(folder.path)")
        }
    }
}

