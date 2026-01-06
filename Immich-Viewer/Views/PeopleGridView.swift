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

// MARK: - Cinematic Theme for Person Detail
private enum PersonDetailTheme {
    static let accent = Color(red: 245/255, green: 166/255, blue: 35/255)
    static let surface = Color(red: 30/255, green: 30/255, blue: 32/255)
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
                // Cinematic background
                SharedGradientBackground()
                
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
                    folderPath: nil,
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
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text("Slideshow")
                        }
                        .foregroundColor(PersonDetailTheme.accent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(PersonDetailTheme.accent.opacity(0.15))
                        )
                    }
                    .disabled(personAssets.isEmpty)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
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
                                .fill(PersonDetailTheme.surface.opacity(0.8))
                        )
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $slideshowTrigger) {
            SlideshowView(albumId: nil, personId: person.id, tagId: nil, city: nil, folderPath: nil, startingAssetId: nil, isFavorite: false)
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
