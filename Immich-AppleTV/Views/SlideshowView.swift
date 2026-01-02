//
//  SlideshowView.swift
//  Immich-AppleTV
//
//  Created by Adrian Kraemer on 2025-06-29.
//

import SwiftUI
import UIKit

struct SlideshowView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel: SlideshowViewModel
    
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    
    // MARK: - Initialization
    
    init(
        assetService: AssetService,
        albumService: AlbumService?,
        albumId: String? = nil,
        personId: String? = nil,
        tagId: String? = nil,
        city: String? = nil,
        startingIndex: Int = 0,
        isFavorite: Bool = false
    ) {
        _viewModel = StateObject(wrappedValue: SlideshowViewModel(
            assetService: assetService,
            albumService: albumService,
            albumId: albumId,
            personId: personId,
            tagId: tagId,
            city: city,
            startingIndex: startingIndex,
            isFavorite: isFavorite
        ))
    }
    
    /// Convenience initializer that creates services internally (for backward compatibility)
    init(
        albumId: String? = nil,
        personId: String? = nil,
        tagId: String? = nil,
        city: String? = nil,
        startingIndex: Int = 0,
        isFavorite: Bool = false
    ) {
        let userManager = UserManager()
        let networkService = NetworkService(userManager: userManager)
        let assetService = AssetService(networkService: networkService)
        let albumService = AlbumService(networkService: networkService)
        
        self.init(
            assetService: assetService,
            albumService: albumService,
            albumId: albumId,
            personId: personId,
            tagId: tagId,
            city: city,
            startingIndex: startingIndex,
            isFavorite: isFavorite
        )
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background color (auto or user-selected)
            viewModel.effectiveBackgroundColor
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: viewModel.dominantColor)
            
            if viewModel.currentImageData == nil && !viewModel.isLoading {
                emptyStateView
            } else if viewModel.isLoading {
                loadingView
            } else if let imageData = viewModel.currentImageData {
                imageContentView(imageData: imageData)
            } else {
                errorView
            }
        }
        .focusable(true)
        .focused($isFocused)
        .onAppear {
            isFocused = true
            UIApplication.shared.isIdleTimerDisabled = true
            debugLog("SlideshowView: Display sleep disabled")
            viewModel.startSlideshow()
        }
        .onDisappear {
            viewModel.cleanup()
            UIApplication.shared.isIdleTimerDisabled = false
            debugLog("SlideshowView: Display sleep re-enabled")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            UIApplication.shared.isIdleTimerDisabled = false
            debugLog("SlideshowView: Display sleep re-enabled (app backgrounded)")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            UIApplication.shared.isIdleTimerDisabled = true
            debugLog("SlideshowView: Display sleep disabled (app foregrounded)")
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            viewModel.reloadSettings()
        }
        .onTapGesture {
            UIApplication.shared.isIdleTimerDisabled = false
            debugLog("SlideshowView: Display sleep re-enabled (tap dismiss)")
            dismiss()
        }
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        VStack {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("No images to display")
                .font(.title)
                .foregroundColor(.white)
        }
    }
    
    private var loadingView: some View {
        ProgressView("Loading...")
            .foregroundColor(.white)
            .scaleEffect(1.5)
    }
    
    private var errorView: some View {
        VStack {
            Image(systemName: "photo")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("Failed to load image")
                .foregroundColor(.gray)
        }
    }
    
    @ViewBuilder
    private func imageContentView(imageData: SlideshowImageData) -> some View {
        GeometryReader { geometry in
            let imageWidth = geometry.size.width * viewModel.settings.dimensionMultiplier
            let imageHeight = geometry.size.height * viewModel.settings.dimensionMultiplier
            
            VStack(spacing: 0) {
                // Main image with performance optimizations
                mainImageView(imageData: imageData, geometry: geometry, imageWidth: imageWidth, imageHeight: imageHeight)
                
                // Reflection
                if viewModel.settings.enableReflections {
                    reflectionView(imageData: imageData, geometry: geometry, imageWidth: imageWidth, imageHeight: imageHeight)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func mainImageView(imageData: SlideshowImageData, geometry: GeometryProxy, imageWidth: CGFloat, imageHeight: CGFloat) -> some View {
        Image(uiImage: imageData.image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: imageWidth, height: imageHeight)
            .drawingGroup()
            .offset(viewModel.isTransitioning ? viewModel.slideDirection.offset(for: geometry.size) : viewModel.kenBurnsOffset)
            .scaleEffect(viewModel.isTransitioning ? viewModel.slideDirection.scale : viewModel.kenBurnsScale)
            .opacity(viewModel.isTransitioning ? viewModel.slideDirection.opacity : 1.0)
            .animation(.easeInOut(duration: viewModel.slideAnimationDuration), value: viewModel.isTransitioning)
            .animation(.linear(duration: viewModel.settings.slideInterval), value: viewModel.kenBurnsScale)
            .animation(.linear(duration: viewModel.settings.slideInterval), value: viewModel.kenBurnsOffset)
            .overlay(
                overlayContent(imageData: imageData, geometry: geometry, imageWidth: imageWidth, imageHeight: imageHeight)
            )
    }
    
    @ViewBuilder
    private func overlayContent(imageData: SlideshowImageData, geometry: GeometryProxy, imageWidth: CGFloat, imageHeight: CGFloat) -> some View {
        if !viewModel.settings.hideOverlay {
            GeometryReader { imageGeometry in
                let actualImageSize = viewModel.calculateActualImageSize(
                    imageSize: CGSize(width: imageData.image.size.width, height: imageData.image.size.height),
                    containerSize: CGSize(width: imageWidth, height: imageHeight)
                )
                let screenWidth = geometry.size.width
                let isSmallWidth = actualImageSize.width < (screenWidth / 2)
                
                if isSmallWidth {
                    // For small images, show overlay outside
                    VStack {
                        HStack {
                            Spacer()
                            LockScreenStyleOverlay(asset: imageData.asset, isSlideshowMode: true)
                                .opacity(viewModel.isTransitioning ? 0.0 : 1.0)
                                .animation(.easeInOut(duration: viewModel.slideAnimationDuration), value: viewModel.isTransitioning)
                        }
                    }
                } else {
                    // For larger images, constrain overlay inside image
                    let xOffset = (imageWidth - actualImageSize.width) / 2
                    let yOffset = (imageHeight - actualImageSize.height) / 2
                    
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            LockScreenStyleOverlay(asset: imageData.asset, isSlideshowMode: true)
                                .opacity(viewModel.isTransitioning ? 0.0 : 1.0)
                                .animation(.easeInOut(duration: viewModel.slideAnimationDuration), value: viewModel.isTransitioning)
                                .padding(.trailing, 20)
                                .padding(.bottom, 20)
                        }
                    }
                    .frame(width: actualImageSize.width, height: actualImageSize.height)
                    .offset(x: xOffset, y: yOffset)
                }
            }
        }
    }
    
    private func reflectionView(imageData: SlideshowImageData, geometry: GeometryProxy, imageWidth: CGFloat, imageHeight: CGFloat) -> some View {
        Image(uiImage: imageData.image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(y: -1)
            .frame(width: imageWidth, height: imageHeight)
            .offset(y: -imageHeight * 0.0)
            .clipped()
            .mask(
                ZStack {
                    LinearGradient(
                        colors: [.black.opacity(0.9), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                    
                    if viewModel.settings.enableKenBurns {
                        Rectangle()
                            .fill(.clear)
                            .background(
                                Rectangle()
                                    .fill(.black)
                                    .scaleEffect(viewModel.isTransitioning ? viewModel.slideDirection.scale : viewModel.kenBurnsScale)
                                    .offset(
                                        x: -(viewModel.isTransitioning ? viewModel.slideDirection.offset(for: geometry.size).width : viewModel.kenBurnsOffset.width),
                                        y: -(viewModel.isTransitioning ? viewModel.slideDirection.offset(for: geometry.size).height : viewModel.kenBurnsOffset.height) - imageHeight
                                    )
                                    .blendMode(.destinationOut)
                            )
                    }
                }
                .compositingGroup()
            )
            .opacity(0.4)
            .drawingGroup()
            .offset(viewModel.isTransitioning ? viewModel.slideDirection.offset(for: geometry.size) : viewModel.kenBurnsOffset)
            .scaleEffect(viewModel.isTransitioning ? viewModel.slideDirection.scale : viewModel.kenBurnsScale)
            .opacity(viewModel.isTransitioning ? viewModel.slideDirection.opacity * 0.4 : 0.4)
            .animation(.easeInOut(duration: viewModel.slideAnimationDuration), value: viewModel.isTransitioning)
            .animation(.linear(duration: viewModel.settings.slideInterval), value: viewModel.kenBurnsScale)
            .animation(.linear(duration: viewModel.settings.slideInterval), value: viewModel.kenBurnsOffset)
    }
}

#Preview {
    UserDefaults.standard.set("auto", forKey: "slideshowBackgroundColor")
    UserDefaults.standard.set("10", forKey: "slideshowInterval")
    UserDefaults.standard.set(true, forKey: "hideImageOverlay")
    UserDefaults.standard.set(true, forKey: "enableReflectionsInSlideshow")
    UserDefaults.standard.set(true, forKey: "enableKenBurnsEffect")
    
    return SlideshowView(albumId: nil, personId: nil, tagId: nil, city: nil, startingIndex: 0, isFavorite: false)
}
