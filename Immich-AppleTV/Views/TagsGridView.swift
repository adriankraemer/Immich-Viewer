import SwiftUI

struct TagsGridView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel: TagsGridViewModel
    
    // MARK: - Services (for child views)
    @ObservedObject var tagService: TagService
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var assetService: AssetService
    
    // MARK: - Thumbnail Provider
    private var thumbnailProvider: TagThumbnailProvider {
        TagThumbnailProvider(assetService: assetService)
    }
    
    // MARK: - Initialization
    
    init(
        tagService: TagService,
        authService: AuthenticationService,
        assetService: AssetService
    ) {
        self.tagService = tagService
        self.authService = authService
        self.assetService = assetService
        
        _viewModel = StateObject(wrappedValue: TagsGridViewModel(
            tagService: tagService
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        SharedGridView(
            items: viewModel.tags,
            config: .tagsStyle,
            thumbnailProvider: thumbnailProvider,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage,
            onItemSelected: { tag in
                viewModel.selectTag(tag)
            },
            onRetry: {
                viewModel.retry()
            }
        )
        .fullScreenCover(item: $viewModel.selectedTag) { tag in
            TagDetailView(tag: tag, assetService: assetService, authService: authService)
        }
        .onAppear {
            viewModel.loadTagsIfNeeded()
        }
    }
}

// MARK: - Tag Detail View

struct TagDetailView: View {
    let tag: Tag
    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                AssetGridView(
                    assetService: assetService,
                    authService: authService,
                    assetProvider: AssetProviderFactory.createProvider(
                        tagId: tag.id,
                        assetService: assetService
                    ),
                    albumId: nil,
                    personId: nil,
                    tagId: tag.id,
                    city: nil,
                    isAllPhotos: false,
                    isFavorite: false,
                    onAssetsLoaded: nil,
                    deepLinkAssetId: nil
                )
            }
            .navigationTitle(tag.name)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let (_, _, authService, assetService, _, _, tagService, _) =
    MockServiceFactory.createMockServices()
    TagsGridView(tagService: tagService, authService: authService, assetService: assetService)
}
