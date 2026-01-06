import SwiftUI

struct CountryDetailView: View {
    @StateObject private var viewModel: CountryViewModel
    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var exploreService: ExploreService
    
    init(country: Country, assetService: AssetService, authService: AuthenticationService, exploreService: ExploreService) {
        _viewModel = StateObject(wrappedValue: CountryViewModel(country: country, assetService: assetService, exploreService: exploreService))
        self.assetService = assetService
        self.authService = authService
        self.exploreService = exploreService
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                AssetGridView(
                    assetService: assetService,
                    authService: authService,
                    assetProvider: viewModel.createAssetProvider(),
                    albumId: nil,
                    personId: nil,
                    tagId: nil,
                    city: nil,
                    folderPath: nil,
                    isAllPhotos: false,
                    isFavorite: false,
                    onAssetsLoaded: nil,
                    deepLinkAssetId: nil,
                    externalSlideshowTrigger: nil
                )
            }
            .navigationTitle(viewModel.countryName)
        }
        .onAppear {
            debugLog("Country detail view for country: \(viewModel.countryName)")
        }
    }
}

