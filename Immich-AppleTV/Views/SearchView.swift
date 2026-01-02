import SwiftUI
import UIKit

struct SearchView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel: SearchViewModel
    
    // MARK: - Services (for child views)
    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    
    // MARK: - Local State
    @State private var showingFullScreen = false
    @FocusState private var focusedAssetId: String?
    
    // MARK: - Layout
    private let columns = [
        GridItem(.fixed(300), spacing: 50),
        GridItem(.fixed(300), spacing: 50),
        GridItem(.fixed(300), spacing: 50),
        GridItem(.fixed(300), spacing: 50),
        GridItem(.fixed(300), spacing: 50),
    ]
    
    // MARK: - Initialization
    
    init(
        searchService: SearchService,
        assetService: AssetService,
        authService: AuthenticationService
    ) {
        self.assetService = assetService
        self.authService = authService
        
        _viewModel = StateObject(wrappedValue: SearchViewModel(
            searchService: searchService,
            assetService: assetService,
            authService: authService
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background
            SharedGradientBackground()
            
            VStack(spacing: 20) {
                // Search results
                if viewModel.isLoading {
                    loadingView
                } else if let errorMessage = viewModel.errorMessage {
                    errorView(message: errorMessage)
                } else if viewModel.showEmptyState {
                    emptyResultsView
                } else if viewModel.showInitialState {
                    initialStateView
                } else {
                    resultsGridView
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search by context: Mountains, sunsets, etc...")
        .onSubmit(of: .search) {
            viewModel.performSearch()
        }
        .fullScreenCover(isPresented: $showingFullScreen) {
            if let selectedAsset = viewModel.selectedAsset {
                FullScreenImageView(
                    asset: selectedAsset,
                    assets: viewModel.assets,
                    currentIndex: viewModel.assets.firstIndex(of: selectedAsset) ?? 0,
                    assetService: assetService,
                    authenticationService: authService,
                    currentAssetIndex: $viewModel.currentAssetIndex
                )
            }
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Searching...")
                .foregroundColor(.white)
                .scaleEffect(1.5)
            Spacer()
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack {
            Spacer()
            VStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                Text("Error")
                    .font(.title)
                    .foregroundColor(.white)
                Text(message)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding()
                Button("Retry") {
                    viewModel.retry()
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
    }
    
    private var emptyResultsView: some View {
        VStack {
            Spacer()
            VStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                Text("No Results Found")
                    .font(.title)
                    .foregroundColor(.white)
                Text("Try different search terms")
                    .foregroundColor(.gray)
            }
            Spacer()
        }
    }
    
    private var initialStateView: some View {
        VStack {
            Spacer()
            VStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                Text("Search Your Photos")
                    .font(.title)
                    .foregroundColor(.white)
                Text("Use the search field to find your photos")
                    .foregroundColor(.gray)
            }
            Spacer()
        }
    }
    
    private var resultsGridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 50) {
                ForEach(viewModel.assets) { asset in
                    assetButton(for: asset)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
    }
    
    private func assetButton(for asset: ImmichAsset) -> some View {
        Button(action: {
            viewModel.selectAsset(asset)
            showingFullScreen = true
        }) {
            AssetThumbnailView(
                asset: asset,
                assetService: assetService,
                isFocused: focusedAssetId == asset.id
            )
        }
        .frame(width: 300, height: 360)
        .id(asset.id)
        .focused($focusedAssetId, equals: asset.id)
        .animation(.easeInOut(duration: 0.2), value: focusedAssetId)
        .buttonStyle(CardButtonStyle())
    }
}
