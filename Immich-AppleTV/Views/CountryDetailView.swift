//
//  CountryDetailView.swift
//  Immich-AppleTV
//
//  View showing photos within a country
//

import SwiftUI

struct CountryDetailView: View {
    @StateObject private var viewModel: CountryViewModel
    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var exploreService: ExploreService
    @Environment(\.dismiss) private var dismiss
    @State private var countryAssets: [ImmichAsset] = []
    @State private var slideshowTrigger: Bool = false
    
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
                    isAllPhotos: false,
                    isFavorite: false,
                    onAssetsLoaded: { loadedAssets in
                        self.countryAssets = loadedAssets
                    },
                    deepLinkAssetId: nil
                )
            }
            .navigationTitle(viewModel.countryName)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: startSlideshow) {
                        Image(systemName: "play.rectangle")
                            .foregroundColor(.white)
                    }
                    .disabled(countryAssets.isEmpty)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .fullScreenCover(isPresented: $slideshowTrigger) {
            SlideshowView(
                albumId: nil,
                personId: nil,
                tagId: nil,
                city: nil,
                startingIndex: 0,
                isFavorite: false
            )
        }
        .onAppear {
            debugLog("Country detail view for country: \(viewModel.countryName)")
        }
    }
    
    private func startSlideshow() {
        // Stop auto-slideshow timer before starting slideshow
        NotificationCenter.default.post(name: NSNotification.Name("stopAutoSlideshowTimer"), object: nil)
        slideshowTrigger = true
    }
}

