import SwiftUI

struct FoldersView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel: FoldersViewModel
    
    // MARK: - Services (for child views)
    @ObservedObject var folderService: FolderService
    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    
    // MARK: - Thumbnail Provider
    private var thumbnailProvider: FolderThumbnailProvider {
        FolderThumbnailProvider(assetService: assetService)
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
        .fullScreenCover(item: $viewModel.selectedFolder) { folder in
            FolderDetailView(folder: folder, assetService: assetService, authService: authService)
        }
        .onAppear {
            viewModel.loadFoldersIfNeeded()
        }
    }
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
