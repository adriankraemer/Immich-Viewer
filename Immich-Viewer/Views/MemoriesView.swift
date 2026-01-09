import SwiftUI

// MARK: - Cinematic Theme Constants for Memories
private enum MemoriesTheme {
    static let accent = Color(red: 245/255, green: 166/255, blue: 35/255)
    static let accentLight = Color(red: 255/255, green: 200/255, blue: 100/255)
    static let surface = Color(red: 30/255, green: 30/255, blue: 32/255)
    static let surfaceLight = Color(red: 45/255, green: 45/255, blue: 48/255)
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 142/255, green: 142/255, blue: 147/255)
    static let textTertiary = Color(red: 99/255, green: 99/255, blue: 102/255)
}

struct MemoriesView: View {
    @StateObject private var viewModel: MemoriesViewModel
    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    
    @State private var loadingRotation: Double = 0
    @FocusState private var focusedMemoryId: String?
    
    // Grid layout - 3 columns for large cards
    private let columns = [
        GridItem(.fixed(550), spacing: 40),
        GridItem(.fixed(550), spacing: 40),
        GridItem(.fixed(550), spacing: 40)
    ]
    
    init(memoriesService: MemoriesService, assetService: AssetService, authService: AuthenticationService) {
        self.assetService = assetService
        self.authService = authService
        _viewModel = StateObject(wrappedValue: MemoriesViewModel(
            memoriesService: memoriesService,
            assetService: assetService
        ))
    }
    
    var body: some View {
        ZStack {
            SharedGradientBackground()
            
            if viewModel.isLoading {
                loadingView
            } else if let errorMessage = viewModel.errorMessage {
                errorView(message: errorMessage)
            } else if viewModel.memories.isEmpty {
                emptyStateView
            } else {
                memoriesGridView
            }
        }
        .fullScreenCover(item: $viewModel.selectedMemory) { memory in
            MemorySlideshowView(
                memory: memory,
                assetService: assetService,
                authService: authService
            )
        }
        .onAppear {
            viewModel.loadMemoriesIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name(NotificationNames.refreshAllTabs))) { _ in
            Task {
                await viewModel.refresh()
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(MemoriesTheme.surface, lineWidth: 4)
                    .frame(width: 70, height: 70)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        AngularGradient(
                            colors: [MemoriesTheme.accent, MemoriesTheme.accentLight],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(loadingRotation))
            }
            
            Text(String(localized: "Loading memories..."))
                .font(.headline)
                .foregroundColor(MemoriesTheme.textSecondary)
        }
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                loadingRotation = 360
            }
        }
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(MemoriesTheme.surface)
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
                Text(String(localized: "Something went wrong"))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(MemoriesTheme.textPrimary)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(MemoriesTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }
            
            Button(action: {
                Task { await viewModel.refresh() }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.clockwise")
                    Text(String(localized: "Try Again"))
                }
                .font(.headline)
                .foregroundColor(.black)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(MemoriesTheme.accent)
                .cornerRadius(12)
            }
            .buttonStyle(CardButtonStyle())
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(MemoriesTheme.surface)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 50))
                    .foregroundColor(MemoriesTheme.textTertiary)
            }
            
            VStack(spacing: 12) {
                Text(String(localized: "No Memories Today"))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(MemoriesTheme.textPrimary)
                
                Text(String(localized: "Photos taken on this day in previous years will appear here"))
                    .font(.body)
                    .foregroundColor(MemoriesTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }
        }
    }
    
    // MARK: - Memories Grid View
    
    private var memoriesGridView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "On This Day"))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(MemoriesTheme.textPrimary)
                    
                    Text(viewModel.todayFormatted)
                        .font(.title3)
                        .foregroundColor(MemoriesTheme.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 60)
            .padding(.top, 40)
            .padding(.bottom, 30)
            
            // Grid of memory cards
            ScrollView {
                LazyVGrid(columns: columns, spacing: 40) {
                    ForEach(viewModel.memories) { memory in
                        Button(action: {
                            viewModel.selectMemory(memory)
                        }) {
                            MemoryCardView(
                                memory: memory,
                                assetService: assetService,
                                isFocused: focusedMemoryId == memory.id
                            )
                        }
                        .buttonStyle(CardButtonStyle())
                        .focused($focusedMemoryId, equals: memory.id)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 60)
            }
        }
    }
}

// MARK: - Memory Card View

struct MemoryCardView: View {
    let memory: Memory
    @ObservedObject var assetService: AssetService
    let isFocused: Bool
    
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    @State private var coverImage: UIImage?
    @State private var isLoadingImage = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Thumbnail section
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(MemoriesTheme.surface.opacity(0.6))
                    .frame(height: 320)
                
                if isLoadingImage {
                    ProgressView()
                        .scaleEffect(1.2)
                } else if let image = coverImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 320)
                        .clipped()
                        .cornerRadius(16)
                        .overlay(
                            // Gradient overlay for text readability
                            LinearGradient(
                                colors: [Color.clear, Color.black.opacity(0.4)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .cornerRadius(16)
                        )
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 40))
                            .foregroundColor(MemoriesTheme.textTertiary)
                    }
                }
            }
            .frame(height: 320)
            
            // Info section
            VStack(alignment: .leading, spacing: 8) {
                Text(memory.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(isFocused ? MemoriesTheme.textPrimary : MemoriesTheme.textSecondary)
                
                Text(memory.formattedDate)
                    .font(.subheadline)
                    .foregroundColor(MemoriesTheme.textTertiary)
                
                HStack(spacing: 6) {
                    Image(systemName: "photo.stack")
                        .font(.caption)
                    Text("\(memory.photoCount) \(memory.photoCount == 1 ? String(localized: "photo") : String(localized: "photos"))")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(MemoriesTheme.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    Color.black.opacity(0.7)
                    LinearGradient(
                        colors: [Color.white.opacity(0.05), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            )
        }
        .frame(width: 550)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            isFocused ? MemoriesTheme.accent.opacity(0.8) : Color.white.opacity(0.1),
                            isFocused ? MemoriesTheme.accent.opacity(0.3) : Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isFocused ? 2.5 : 1
                )
        )
        .onAppear {
            loadCoverImage()
        }
    }
    
    private func loadCoverImage() {
        guard let coverAsset = memory.coverAsset else {
            isLoadingImage = false
            return
        }
        
        Task {
            do {
                let image = try await thumbnailCache.getThumbnail(for: coverAsset.id, size: "preview") {
                    try await assetService.loadImage(assetId: coverAsset.id, size: "preview")
                }
                await MainActor.run {
                    self.coverImage = image
                    self.isLoadingImage = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingImage = false
                }
                debugLog("MemoryCardView: Failed to load cover image: \(error)")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let userManager = UserManager()
    let networkService = NetworkService(userManager: userManager)
    let memoriesService = MemoriesService(networkService: networkService)
    let assetService = AssetService(networkService: networkService)
    let authService = AuthenticationService(networkService: networkService, userManager: userManager)
    
    return MemoriesView(
        memoriesService: memoriesService,
        assetService: assetService,
        authService: authService
    )
}
