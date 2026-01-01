//
//  WorldMapView.swift
//  Immich Gallery
//
//  Map view displaying photo locations on a world map
//

import SwiftUI
import MapKit

struct WorldMapView: View {
    @ObservedObject var mapService: MapService
    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    
    @StateObject private var viewModel: WorldMapViewModel
    
    init(mapService: MapService, assetService: AssetService, authService: AuthenticationService) {
        self.mapService = mapService
        self.assetService = assetService
        self.authService = authService
        _viewModel = StateObject(wrappedValue: WorldMapViewModel(mapService: mapService, assetService: assetService))
    }
    
    var body: some View {
        ZStack {
            SharedGradientBackground()
            
            if viewModel.isLoading {
                ProgressView("Loading map data...")
                    .foregroundColor(.white)
                    .scaleEffect(1.5)
            } else if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    Text("Error")
                        .font(.title)
                        .foregroundColor(.white)
                    Text(errorMessage)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Retry") {
                        Task {
                            await viewModel.refresh()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if viewModel.clusters.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "map")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No Location Data")
                        .font(.title)
                        .foregroundColor(.white)
                    Text("Photos with location data will appear on the map")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            } else {
                ZStack {
                    Map(coordinateRegion: $viewModel.region, annotationItems: viewModel.clusters) { cluster in
                        MapAnnotation(coordinate: cluster.coordinate) {
                            ClusterAnnotationView(
                                cluster: cluster,
                                assetService: assetService,
                                mapSpan: viewModel.region.span
                            )
                        }
                    }
                    #if os(iOS) || os(macOS)
                    .mapStyle(.standard(elevation: .realistic))
                    #endif
                    
                    // Brief navigation legend
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack(alignment: .trailing, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "hand.draw")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                    Text("Touchpad: Pan")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                HStack(spacing: 6) {
                                    Image(systemName: "playpause.fill")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                    Text("Play/Pause: Zoom In")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                HStack(spacing: 6) {
                                    Image(systemName: "hand.tap")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                    Text("Long Press: Zoom Out")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                            .padding(.trailing, 30)
                            .padding(.bottom, 30)
                        }
                    }
                }
                .background(
                    MapPanGestureView { direction in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.pan(direction: direction)
                        }
                    }
                )
                .focusable()
                .onPlayPauseCommand {
                    // Zoom in with play/pause
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.zoomIn()
                    }
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 1.0)
                        .onEnded { _ in
                            // Zoom out with long press (1 second) on touchpad
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.zoomOut()
                            }
                        }
                )
            }
        }
        .onAppear {
            if viewModel.clusters.isEmpty {
                Task {
                    await viewModel.loadMapData()
                }
            }
        }
    }
}

// MARK: - Cluster Annotation View
struct ClusterAnnotationView: View {
    let cluster: PhotoCluster
    @ObservedObject var assetService: AssetService
    let mapSpan: MKCoordinateSpan
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    @State private var thumbnailImages: [String: UIImage] = [:]
    @State private var loadingAssets: Set<String> = []
    @State private var previousZoomState: Bool?
    @State private var loadingTasks: [String: Task<Void, Never>] = [:]
    @State private var debounceTask: Task<Void, Never>?
    
    // Size configuration
    private let imageSize: CGFloat = 80
    private let maxDisplayCount = 5
    private let spreadRadius: CGFloat = 45 // Distance from center for multiple images
    
    // Threshold for showing multiple images (smaller span = more zoomed in)
    // Only show multiple images when span is less than 5 degrees (zoomed in)
    private let multiImageZoomThreshold: Double = 5.0
    
    var isZoomedIn: Bool {
        let avgSpan = (mapSpan.latitudeDelta + mapSpan.longitudeDelta) / 2
        return avgSpan < multiImageZoomThreshold
    }
    
    var displayAssets: [ImmichAsset] {
        // Get unique assets (in case of duplicates)
        var uniqueAssets: [ImmichAsset] = []
        var seenIds: Set<String> = []
        
        for asset in cluster.assets {
            if !seenIds.contains(asset.id) {
                uniqueAssets.append(asset)
                seenIds.insert(asset.id)
            }
        }
        
        // Only show multiple images when zoomed in
        if isZoomedIn && uniqueAssets.count > 1 {
            return Array(uniqueAssets.prefix(maxDisplayCount))
        } else {
            // When zoomed out or only one image, show just the first one
            return Array(uniqueAssets.prefix(1))
        }
    }
    
    var body: some View {
        ZStack {
            if displayAssets.count == 1 {
                // Single image - display centered
                SingleImageView(
                    asset: displayAssets[0],
                    imageSize: imageSize,
                    thumbnailImage: thumbnailImages[displayAssets[0].id],
                    isLoading: loadingAssets.contains(displayAssets[0].id),
                    thumbnailCache: thumbnailCache,
                    assetService: assetService
                )
            } else {
                // Multiple images - arrange in a circle
                ForEach(Array(displayAssets.enumerated()), id: \.element.id) { index, asset in
                    let angle = Double(index) * 2.0 * .pi / Double(displayAssets.count)
                    let offsetX = cos(angle) * spreadRadius
                    let offsetY = sin(angle) * spreadRadius
                    
                    SingleImageView(
                        asset: asset,
                        imageSize: imageSize,
                        thumbnailImage: thumbnailImages[asset.id],
                        isLoading: loadingAssets.contains(asset.id),
                        thumbnailCache: thumbnailCache,
                        assetService: assetService
                    )
                    .offset(x: offsetX, y: offsetY)
                }
            }
        }
        .onAppear {
            previousZoomState = isZoomedIn
            loadThumbnails()
        }
        .onChange(of: mapSpan.latitudeDelta) { _ in
            handleZoomChange()
        }
        .onChange(of: mapSpan.longitudeDelta) { _ in
            handleZoomChange()
        }
        .onDisappear {
            // Cancel all loading tasks when view disappears
            cancelAllLoading()
        }
    }
    
    private func handleZoomChange() {
        // Cancel previous debounce task
        debounceTask?.cancel()
        
        // Debounce the zoom change check
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms debounce
            
            // Check if zoom state actually changed (crossed threshold)
            let currentZoomState = isZoomedIn
            if previousZoomState != currentZoomState {
                previousZoomState = currentZoomState
                // Only reload if display mode changed
                loadThumbnails()
            }
        }
    }
    
    private func loadThumbnails() {
        let assetsToLoad = displayAssets
        
        // Cancel loading for assets that are no longer needed
        for (assetId, task) in loadingTasks {
            if !assetsToLoad.contains(where: { $0.id == assetId }) {
                task.cancel()
                loadingTasks.removeValue(forKey: assetId)
                loadingAssets.remove(assetId)
            }
        }
        
        // Load thumbnails for current display assets
        for asset in assetsToLoad {
            // Skip if already loaded or currently loading
            guard thumbnailImages[asset.id] == nil && !loadingAssets.contains(asset.id) else {
                continue
            }
            
            loadingAssets.insert(asset.id)
            
            let task = Task {
                do {
                    let thumbnail = try await thumbnailCache.getThumbnail(for: asset.id, size: "thumbnail") {
                        return try await assetService.loadImage(assetId: asset.id, size: "thumbnail")
                    }
                    
                    // Check if task was cancelled before updating UI
                    try Task.checkCancellation()
                    
                    await MainActor.run {
                        self.thumbnailImages[asset.id] = thumbnail
                        self.loadingAssets.remove(asset.id)
                        self.loadingTasks.removeValue(forKey: asset.id)
                    }
                } catch is CancellationError {
                    // Task was cancelled - clean up silently
                    await MainActor.run {
                        self.loadingAssets.remove(asset.id)
                        self.loadingTasks.removeValue(forKey: asset.id)
                    }
                } catch {
                    print("Failed to load thumbnail for asset \(asset.id): \(error)")
                    await MainActor.run {
                        self.loadingAssets.remove(asset.id)
                        self.loadingTasks.removeValue(forKey: asset.id)
                    }
                }
            }
            
            loadingTasks[asset.id] = task
        }
    }
    
    private func cancelAllLoading() {
        debounceTask?.cancel()
        for task in loadingTasks.values {
            task.cancel()
        }
        loadingTasks.removeAll()
        loadingAssets.removeAll()
    }
}

// MARK: - Single Image View Component
struct SingleImageView: View {
    let asset: ImmichAsset
    let imageSize: CGFloat
    let thumbnailImage: UIImage?
    let isLoading: Bool
    @ObservedObject var thumbnailCache: ThumbnailCache
    @ObservedObject var assetService: AssetService
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.8))
                .frame(width: imageSize + 10, height: imageSize + 10)
            
            if isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: imageSize, height: imageSize)
            } else if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageSize, height: imageSize)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
            } else {
                Image(systemName: "photo.stack")
                    .foregroundColor(.white)
                    .frame(width: imageSize, height: imageSize)
            }
        }
    }
}

// MARK: - Cluster Detail View
struct ClusterDetailView: View {
    let cluster: PhotoCluster
    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAsset: ImmichAsset?
    @State private var showingFullScreen = false
    @State private var currentAssetIndex: Int = 0
    
    var body: some View {
        ZStack {
            SharedGradientBackground()
            
            VStack {
                HStack {
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                    
                    Spacer()
                    
                    Text("\(cluster.photoCount) Photos")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                    
                    Spacer()
                }
                
                // Display assets in a grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 20),
                        GridItem(.flexible(), spacing: 20),
                        GridItem(.flexible(), spacing: 20)
                    ], spacing: 20) {
                        ForEach(Array(cluster.assets.enumerated()), id: \.element.id) { index, asset in
                            AssetThumbnailView(
                                asset: asset,
                                assetService: assetService,
                                isFocused: false
                            )
                            .onTapGesture {
                                selectedAsset = asset
                                currentAssetIndex = index
                                showingFullScreen = true
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .fullScreenCover(isPresented: $showingFullScreen) {
            if let asset = selectedAsset {
                FullScreenImageView(
                    asset: asset,
                    assets: cluster.assets,
                    currentIndex: currentAssetIndex,
                    assetService: assetService,
                    authenticationService: authService,
                    currentAssetIndex: $currentAssetIndex
                )
            }
        }
    }
}

#Preview {
    let userManager = UserManager()
    let networkService = NetworkService(userManager: userManager)
    let mapService = MapService(networkService: networkService)
    let assetService = AssetService(networkService: networkService)
    let authService = AuthenticationService(networkService: networkService, userManager: userManager)
    
    return WorldMapView(
        mapService: mapService,
        assetService: assetService,
        authService: authService
    )
}




