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
                    onAssetsLoaded: nil,
                    deepLinkAssetId: nil
                )
            }
            .navigationTitle(person.name.isEmpty ? "Unknown Person" : person.name)
            .toolbar {
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
    }
}

// MARK: - Preview

#Preview {
    let (_, _, authService, assetService, _, peopleService, _, _) =
         MockServiceFactory.createMockServices()
    PeopleGridView(peopleService: peopleService, authService: authService, assetService: assetService)
}
