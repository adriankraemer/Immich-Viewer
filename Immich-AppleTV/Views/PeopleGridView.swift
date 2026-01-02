//
//  PeopleGridView.swift
//  Immich-AppleTV
//
//  Created by Adrian Kraemer on 2025-06-29.
//

import SwiftUI

struct PeopleGridView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel: PeopleGridViewModel
    
    // MARK: - Services (for child views)
    @ObservedObject var peopleService: PeopleService
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var assetService: AssetService
    
    // MARK: - Thumbnail Provider
    private var thumbnailProvider: PeopleThumbnailProvider {
        PeopleThumbnailProvider(assetService: assetService)
    }
    
    // MARK: - Initialization
    
    init(
        peopleService: PeopleService,
        authService: AuthenticationService,
        assetService: AssetService
    ) {
        self.peopleService = peopleService
        self.authService = authService
        self.assetService = assetService
        
        _viewModel = StateObject(wrappedValue: PeopleGridViewModel(
            peopleService: peopleService,
            authService: authService
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        SharedGridView(
            items: viewModel.people,
            config: .peopleStyle,
            thumbnailProvider: thumbnailProvider,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage,
            onItemSelected: { person in
                viewModel.selectPerson(person)
            },
            onRetry: {
                viewModel.retry()
            }
        )
        .fullScreenCover(item: $viewModel.selectedPerson) { person in
            PersonPhotosView(
                person: person,
                peopleService: peopleService,
                authService: authService,
                assetService: assetService
            )
        }
        .onAppear {
            viewModel.loadPeopleIfNeeded()
        }
    }
}

// MARK: - Person Photos View

struct PersonPhotosView: View {
    let person: Person
    @ObservedObject var peopleService: PeopleService
    @ObservedObject var authService: AuthenticationService
    @ObservedObject var assetService: AssetService
    @Environment(\.dismiss) private var dismiss
    @State private var personAssets: [ImmichAsset] = []
    @State private var slideshowTrigger: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                AssetGridView(
                    assetService: assetService,
                    authService: authService,
                    assetProvider: AssetProviderFactory.createProvider(
                        personId: person.id,
                        assetService: assetService
                    ),
                    albumId: nil,
                    personId: person.id,
                    tagId: nil,
                    city: nil,
                    isAllPhotos: false,
                    isFavorite: false,
                    onAssetsLoaded: { loadedAssets in
                        self.personAssets = loadedAssets
                    },
                    deepLinkAssetId: nil
                )
            }
            .navigationTitle(person.name.isEmpty ? "Unknown Person" : person.name)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: startSlideshow) {
                        Image(systemName: "play.rectangle")
                            .foregroundColor(.white)
                    }
                    .disabled(personAssets.isEmpty)
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
            SlideshowView(albumId: nil, personId: person.id, tagId: nil, city: nil, startingAssetId: nil, isFavorite: false)
        }
    }
    
    private func startSlideshow() {
        // Stop auto-slideshow timer before starting slideshow
        NotificationCenter.default.post(name: NSNotification.Name("stopAutoSlideshowTimer"), object: nil)
        slideshowTrigger = true
    }
}

// MARK: - Preview

#Preview {
    let (_, _, authService, assetService, _, peopleService, _, _) =
         MockServiceFactory.createMockServices()
    PeopleGridView(peopleService: peopleService, authService: authService, assetService: assetService)
}
