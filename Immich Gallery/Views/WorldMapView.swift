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
    @State private var selectedCluster: PhotoCluster?
    @State private var showingClusterDetail = false
    
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
                            ClusterAnnotationView(cluster: cluster, assetService: assetService)
                                .onTapGesture {
                                    selectedCluster = cluster
                                    showingClusterDetail = true
                                }
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
        .fullScreenCover(isPresented: $showingClusterDetail) {
            if let cluster = selectedCluster {
                ClusterDetailView(
                    cluster: cluster,
                    assetService: assetService,
                    authService: authService
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
    @ObservedObject private var thumbnailCache = ThumbnailCache.shared
    @State private var thumbnailImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.8))
                .frame(width: 50, height: 50)
            
            if isLoading {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 40, height: 40)
            } else if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else {
                Image(systemName: "photo.stack")
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        guard let asset = cluster.representativeAsset else {
            isLoading = false
            return
        }
        
        Task {
            do {
                let thumbnail = try await thumbnailCache.getThumbnail(for: asset.id, size: "thumbnail") {
                    return try await assetService.loadImage(assetId: asset.id, size: "thumbnail")
                }
                
                await MainActor.run {
                    self.thumbnailImage = thumbnail
                    self.isLoading = false
                }
            } catch {
                print("Failed to load thumbnail for cluster: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
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


