import SwiftUI
import UIKit

// MARK: - Cinematic Theme Constants for Search
private enum SearchTheme {
    static let accent = Color(red: 245/255, green: 166/255, blue: 35/255)
    static let surface = Color(red: 30/255, green: 30/255, blue: 32/255)
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 142/255, green: 142/255, blue: 147/255)
    static let textTertiary = Color(red: 99/255, green: 99/255, blue: 102/255)
}

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
    
    // MARK: - Cinematic Subviews
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Cinematic loading animation
            ZStack {
                Circle()
                    .stroke(SearchTheme.surface, lineWidth: 4)
                    .frame(width: 70, height: 70)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        AngularGradient(
                            colors: [SearchTheme.accent, SearchTheme.accent.opacity(0.3)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(searchLoadingRotation))
            }
            
            Text("Searching...")
                .font(.headline)
                .foregroundColor(SearchTheme.textSecondary)
            
            Spacer()
        }
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                searchLoadingRotation = 360
            }
        }
    }
    
    @State private var searchLoadingRotation: Double = 0
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(SearchTheme.surface)
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
                Text("Search Failed")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(SearchTheme.textPrimary)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(SearchTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }
            
            Button(action: { viewModel.retry() }) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.headline)
                .foregroundColor(.black)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(SearchTheme.accent)
                .cornerRadius(12)
            }
            .buttonStyle(CardButtonStyle())
            
            Spacer()
        }
    }
    
    private var emptyResultsView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(SearchTheme.surface)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 50))
                    .foregroundColor(SearchTheme.textTertiary)
            }
            
            VStack(spacing: 12) {
                Text("No Results Found")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(SearchTheme.textPrimary)
                
                Text("Try different search terms")
                    .font(.body)
                    .foregroundColor(SearchTheme.textSecondary)
            }
            
            Spacer()
        }
    }
    
    private var initialStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                // Outer glow
                Circle()
                    .fill(SearchTheme.accent.opacity(0.1))
                    .frame(width: 160, height: 160)
                
                Circle()
                    .fill(SearchTheme.surface)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundColor(SearchTheme.accent)
            }
            
            VStack(spacing: 12) {
                Text("Search Your Photos")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(SearchTheme.textPrimary)
                
                Text("Use the search field to find photos by context")
                    .font(.body)
                    .foregroundColor(SearchTheme.textSecondary)
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
