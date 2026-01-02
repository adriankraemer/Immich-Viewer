//
//  FoldersView.swift
//  Immich-AppleTV
//
//  Created by Codex on 2025-09-12.
//

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
                Color.black
                    .ignoresSafeArea()
                
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
                    isAllPhotos: false,
                    isFavorite: false,
                    onAssetsLoaded: nil,
                    deepLinkAssetId: nil
                )
            }
            .navigationTitle(folderTitle)
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
    let (_, _, authService, assetService, _, _, _, folderService) =
    MockServiceFactory.createMockServices()
    return FoldersView(folderService: folderService, assetService: assetService, authService: authService)
}
