//
//  FullScreenImageViewModel.swift
//  Immich-AppleTV
//
//  ViewModel for FullScreenImage feature following MVVM pattern
//  Handles image loading, navigation, and state management
//

import Foundation
import SwiftUI
import Combine

@MainActor
class FullScreenImageViewModel: ObservableObject {
    // MARK: - Published Properties (View State)
    @Published var image: UIImage?
    @Published var isLoading = true
    @Published var currentAsset: ImmichAsset
    @Published var showingSwipeHint = false
    @Published var showingVideoPlayer = false
    @Published var showingExifInfo = false
    @Published var refreshToggle = false
    
    // MARK: - Dependencies
    private let assetService: AssetService
    
    // MARK: - Configuration
    let initialAsset: ImmichAsset
    let assets: [ImmichAsset]
    let initialIndex: Int
    
    // MARK: - Callbacks
    var onCurrentIndexChanged: ((Int) -> Void)?
    
    // MARK: - Internal State
    private var currentIndex: Int
    
    // MARK: - Computed Properties
    
    var isVideo: Bool {
        currentAsset.type == .video
    }
    
    var canNavigateLeft: Bool {
        currentIndex > 0
    }
    
    var canNavigateRight: Bool {
        currentIndex < assets.count - 1
    }
    
    var hasMultipleAssets: Bool {
        assets.count > 1
    }
    
    var currentAssetIndex: Int {
        currentIndex
    }
    
    // MARK: - Initialization
    
    init(
        asset: ImmichAsset,
        assets: [ImmichAsset],
        currentIndex: Int,
        assetService: AssetService,
        onCurrentIndexChanged: ((Int) -> Void)? = nil
    ) {
        debugLog("FullScreenImageViewModel: Initializing with currentIndex: \(currentIndex)")
        self.initialAsset = asset
        self.assets = assets
        self.initialIndex = currentIndex
        self.assetService = assetService
        self.onCurrentIndexChanged = onCurrentIndexChanged
        self.currentIndex = currentIndex
        self.currentAsset = asset
    }
    
    // MARK: - Public Methods
    
    /// Loads the full resolution image for the current asset
    func loadFullImage() {
        guard currentAsset.type != .video else { return }
        
        Task {
            do {
                debugLog("FullScreenImageViewModel: Loading full image for asset \(currentAsset.id)")
                let fullImage = try await assetService.loadFullImage(asset: currentAsset)
                debugLog("FullScreenImageViewModel: Loaded image for asset \(currentAsset.id)")
                self.image = fullImage
                self.isLoading = false
            } catch {
                debugLog("FullScreenImageViewModel: Failed to load full image for asset \(currentAsset.id): \(error)")
                self.isLoading = false
            }
        }
    }
    
    /// Navigates to the image at the specified index
    func navigateToImage(at index: Int) {
        debugLog("FullScreenImageViewModel: Attempting to navigate to image at index \(index) (total assets: \(assets.count))")
        guard index >= 0 && index < assets.count else {
            debugLog("FullScreenImageViewModel: Navigation failed - index \(index) out of bounds")
            return
        }
        
        debugLog("FullScreenImageViewModel: Navigating to asset ID: \(assets[index].id)")
        currentIndex = index
        onCurrentIndexChanged?(index)
        debugLog("FullScreenImageViewModel: Updated currentAssetIndex to \(index)")
        
        currentAsset = assets[index]
        refreshToggle.toggle() // Force UI update
        
        // Reset overlay states when navigating
        showingExifInfo = false
        if currentAsset.type == .video {
            showingVideoPlayer = false
        } else {
            image = nil
            isLoading = true
            loadFullImage()
        }
    }
    
    /// Navigates to the previous image
    func navigateLeft() {
        debugLog("FullScreenImageViewModel: Left navigation triggered (current: \(currentIndex), total: \(assets.count))")
        if canNavigateLeft {
            navigateToImage(at: currentIndex - 1)
        } else {
            debugLog("FullScreenImageViewModel: Already at first photo, cannot navigate further")
        }
    }
    
    /// Navigates to the next image
    func navigateRight() {
        debugLog("FullScreenImageViewModel: Right navigation triggered (current: \(currentIndex), total: \(assets.count))")
        if canNavigateRight {
            navigateToImage(at: currentIndex + 1)
        } else {
            debugLog("FullScreenImageViewModel: Already at last photo, cannot navigate further")
        }
    }
    
    /// Toggles the EXIF info overlay
    func toggleExifInfo() {
        debugLog("FullScreenImageViewModel: Toggling EXIF info")
        showingExifInfo.toggle()
    }
    
    /// Hides the EXIF info overlay
    func hideExifInfo() {
        debugLog("FullScreenImageViewModel: Hiding EXIF info")
        if showingExifInfo {
            showingExifInfo = false
        }
    }
    
    /// Shows the video player
    func showVideoPlayer() {
        debugLog("FullScreenImageViewModel: Showing video player")
        showingVideoPlayer = true
    }
    
    /// Hides the video player
    func hideVideoPlayer() {
        debugLog("FullScreenImageViewModel: Hiding video player")
        showingVideoPlayer = false
    }
    
    /// Shows the swipe hint temporarily
    func showSwipeHintIfNeeded() {
        guard hasMultipleAssets else { return }
        
        showingSwipeHint = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.showingSwipeHint = false
        }
    }
    
    /// Handles tap gesture based on current content type
    func handleTap() {
        debugLog("FullScreenImageViewModel: Tap gesture detected - isVideo: \(isVideo)")
        if isVideo {
            showVideoPlayer()
        }
    }
    
    /// Handles the exit command
    /// Returns true if the view should dismiss, false if it handled internally
    func handleExitCommand() -> Bool {
        debugLog("FullScreenImageViewModel: Exit command triggered")
        if showingVideoPlayer {
            hideVideoPlayer()
            return false
        }
        debugLog("FullScreenImageViewModel: Dismissing fullscreen view")
        return true
    }
}

