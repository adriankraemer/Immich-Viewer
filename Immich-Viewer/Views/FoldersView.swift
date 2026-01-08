import SwiftUI

struct FoldersView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel: FoldersViewModel
    
    // MARK: - Services (for child views)
    @ObservedObject var folderService: FolderService
    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    
    // MARK: - Settings
    @AppStorage("folderViewMode") private var folderViewMode = "grid"
    
    // MARK: - Thumbnail Provider
    private var thumbnailProvider: FolderThumbnailProvider {
        FolderThumbnailProvider(assetService: assetService)
    }
    
    // MARK: - Computed Properties
    private var currentViewMode: FolderViewMode {
        FolderViewMode(rawValue: folderViewMode) ?? .grid
    }
    
    // MARK: - Initialization
    
    init(
        folderService: FolderService,
        assetService: AssetService,
        authService: AuthenticationService
    ) {
        self.folderService = folderService
        self.assetService = assetService
        self.authService = authService
        
        _viewModel = StateObject(wrappedValue: FoldersViewModel(
            folderService: folderService
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background
            SharedGradientBackground()
            
            // Content based on view mode
            viewContent
        }
        .fullScreenCover(item: $viewModel.selectedFolder) { folder in
            FolderDetailView(folder: folder, assetService: assetService, authService: authService)
        }
        .onAppear {
            viewModel.loadFoldersIfNeeded()
        }
        .onChange(of: folderViewMode) { _, _ in
            // Ensure data is loaded for the new view mode
            viewModel.ensureDataForViewMode()
        }
    }
    
    @ViewBuilder
    private var viewContent: some View {
        switch currentViewMode {
        case .grid:
            gridView
        case .tree:
            treeView
        case .timeline:
            timelineView
        }
    }
    
    // MARK: - Grid View (Original)
    
    private var gridView: some View {
        SharedGridView(
            items: viewModel.folders,
            config: .foldersStyle,
            thumbnailProvider: thumbnailProvider,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage,
            onItemSelected: { folder in
                viewModel.selectFolder(folder)
            },
            onRetry: {
                viewModel.retry()
            }
        )
    }
    
    // MARK: - Tree View
    
    @ViewBuilder
    private var treeView: some View {
        if viewModel.isLoading {
            loadingView
        } else if let error = viewModel.errorMessage {
            errorView(error)
        } else if viewModel.folderTree.isEmpty {
            emptyView
        } else {
            FolderTreeView(
                folders: viewModel.folderTree,
                onFolderSelected: { folder in
                    viewModel.selectFolder(folder)
                }
            )
        }
    }
    
    // MARK: - Timeline View
    
    @ViewBuilder
    private var timelineView: some View {
        if viewModel.isLoading {
            loadingView
        } else if let error = viewModel.errorMessage {
            errorView(error)
        } else {
            FolderTimelineView(
                timelineGroups: viewModel.timelineGroups,
                isLoading: viewModel.isLoadingTimeline,
                onFolderSelected: { folder in
                    viewModel.selectFolder(folder)
                }
            )
            .onAppear {
                // Load timeline data when view appears
                viewModel.ensureDataForViewMode()
            }
        }
    }
    
    // MARK: - Shared Views
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(FolderViewTheme.accent)
            
            Text("Loading folders...")
                .font(.headline)
                .foregroundColor(FolderViewTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(FolderViewTheme.accent)
            
            Text("Error Loading Folders")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(FolderViewTheme.textPrimary)
            
            Text(message)
                .font(.body)
                .foregroundColor(FolderViewTheme.textSecondary)
                .multilineTextAlignment(.center)
            
            Button(action: { viewModel.retry() }) {
                Text("Retry")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(FolderViewTheme.accent)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 60))
                .foregroundColor(FolderViewTheme.textSecondary)
            
            Text("No Folders Found")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(FolderViewTheme.textPrimary)
            
            Text("Folders with indexed assets will appear here")
                .font(.body)
                .foregroundColor(FolderViewTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Theme Constants
private enum FolderViewTheme {
    static let accent = Color(red: 245/255, green: 166/255, blue: 35/255)
    static let surface = Color(red: 30/255, green: 30/255, blue: 32/255)
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 142/255, green: 142/255, blue: 147/255)
}

// MARK: - Cinematic Theme for Folder Detail
private enum FolderDetailTheme {
    static let accent = Color(red: 245/255, green: 166/255, blue: 35/255)
    static let surface = Color(red: 30/255, green: 30/255, blue: 32/255)
}

// MARK: - Folder Detail View

struct FolderDetailView: View {
    let folder: ImmichFolder
    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss
    
    private var folderTitle: String {
        folder.primaryTitle.isEmpty ? folder.path : folder.primaryTitle
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Cinematic background
                SharedGradientBackground()
                
                AssetGridView(
                    assetService: assetService,
                    authService: authService,
                    assetProvider: AssetProviderFactory.createProvider(
                        folderPath: folder.path,
                        assetService: assetService
                    ),
                    albumId: nil,
                    personId: nil,
                    tagId: nil,
                    city: nil,
                    folderPath: folder.path,
                    isAllPhotos: false,
                    isFavorite: false,
                    onAssetsLoaded: nil,
                    deepLinkAssetId: nil
                )
            }
            .navigationTitle(folderTitle)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark")
                            Text("Close")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(FolderDetailTheme.surface.opacity(0.8))
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let (_, _, authService, assetService, _, _, _, folderService) =
    MockServiceFactory.createMockServices()
    return FoldersView(folderService: folderService, assetService: assetService, authService: authService)
}
