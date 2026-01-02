//
//  SimpleVideoPlayerViewModel.swift
//  Immich-AppleTV
//
//  ViewModel for SimpleVideoPlayer feature following MVVM pattern
//  Handles video loading and playback state management with optimized buffering
//

import Foundation
import SwiftUI
import AVKit
import Combine

@MainActor
class SimpleVideoPlayerViewModel: ObservableObject {
    // MARK: - Published Properties (View State)
    @Published var player: AVPlayer?
    @Published var isLoading = true
    @Published var isBuffering = false
    @Published var errorMessage: String?
    @Published var loadingProgress: Double = 0.0
    
    // MARK: - Dependencies
    private let assetService: AssetService
    private let authenticationService: AuthenticationService
    
    // MARK: - Configuration
    let asset: ImmichAsset
    
    // MARK: - Internal State
    private var hasAttemptedLoad = false
    private var playerItem: AVPlayerItem?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        asset: ImmichAsset,
        assetService: AssetService,
        authenticationService: AuthenticationService
    ) {
        self.asset = asset
        self.assetService = assetService
        self.authenticationService = authenticationService
    }
    
    // MARK: - Public Methods
    
    /// Loads the video if not already loaded
    func loadVideoIfNeeded(force: Bool = false) async {
        guard !hasAttemptedLoad || force else { return }
        
        hasAttemptedLoad = true
        isLoading = true
        isBuffering = false
        errorMessage = nil
        loadingProgress = 0.0
        
        debugLog("SimpleVideoPlayerViewModel: Loading video for asset \(asset.id)")
        
        do {
            let videoURL = try await assetService.loadVideoURL(asset: asset)
            let headers = authenticationService.getAuthHeaders()
            
            // Create AVURLAsset with optimized options
            var assetOptions: [String: Any] = [:]
            if !headers.isEmpty {
                assetOptions["AVURLAssetHTTPHeaderFieldsKey"] = headers
            }
            
            let urlAsset = AVURLAsset(url: videoURL, options: assetOptions)
            
            // Pre-load essential properties for faster startup using modern async API
            let isPlayable = try await urlAsset.load(.isPlayable)
            if !isPlayable {
                throw ImmichError.videoPlaybackFailed
            }
            
            // Load duration for progress tracking
            _ = try? await urlAsset.load(.duration)
            
            // Create player item with buffer optimization
            let playerItem = AVPlayerItem(asset: urlAsset)
            self.playerItem = playerItem
            
            // Configure buffer settings for smoother playback
            configureBufferSettings(playerItem)
            
            // Set up observers
            setupPlayerItemObservers(playerItem)
            
            // Create and configure player
            let player = AVPlayer(playerItem: playerItem)
            player.automaticallyWaitsToMinimizeStalling = true
            
            debugLog("SimpleVideoPlayerViewModel: Video loaded successfully, waiting for buffer")
            self.player = player
            self.isLoading = false
            
            // Don't auto-play - wait for buffer to fill
            // Player will auto-play when buffer is ready (handled by observer)
            
        } catch {
            debugLog("SimpleVideoPlayerViewModel: Failed to load video: \(error)")
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
    
    /// Retries loading the video
    func retry() async {
        cleanup()
        await loadVideoIfNeeded(force: true)
    }
    
    /// Starts playback
    func play() {
        player?.play()
    }
    
    /// Pauses playback
    func pause() {
        player?.pause()
    }
    
    /// Cleans up the player
    func cleanup() {
        debugLog("SimpleVideoPlayerViewModel: Cleaning up player")
        
        // Cancel all subscriptions
        cancellables.removeAll()
        
        // Clean up player
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        playerItem = nil
        hasAttemptedLoad = false
    }
    
    // MARK: - Private Methods
    
    private func configureBufferSettings(_ playerItem: AVPlayerItem) {
        // Set preferred buffer duration (in seconds)
        // Higher value = more buffering before playback, but smoother playback
        playerItem.preferredForwardBufferDuration = 10.0
        
        // Configure for network streaming
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        
        // Set preferred peak bit rate (0 = no limit, let it adapt)
        playerItem.preferredPeakBitRate = 0
        
        // For 4K content, you might want to limit this:
        // playerItem.preferredMaximumResolution = CGSize(width: 1920, height: 1080)
        
        debugLog("SimpleVideoPlayerViewModel: Buffer configured - forward duration: 10s")
    }
    
    private func setupPlayerItemObservers(_ playerItem: AVPlayerItem) {
        // Observe playback buffer status
        playerItem.publisher(for: \.isPlaybackBufferEmpty)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEmpty in
                if isEmpty {
                    debugLog("SimpleVideoPlayerViewModel: Buffer empty - pausing for rebuffer")
                    self?.isBuffering = true
                }
            }
            .store(in: &cancellables)
        
        // Observe when buffer has enough data to resume
        playerItem.publisher(for: \.isPlaybackLikelyToKeepUp)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLikelyToKeepUp in
                guard let self = self else { return }
                if isLikelyToKeepUp {
                    debugLog("SimpleVideoPlayerViewModel: Buffer ready - playback can continue")
                    self.isBuffering = false
                    // Auto-play when buffer is ready
                    if self.player?.rate == 0 && self.player?.currentItem?.status == .readyToPlay {
                        self.player?.play()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Observe buffer full status
        playerItem.publisher(for: \.isPlaybackBufferFull)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isFull in
                if isFull {
                    debugLog("SimpleVideoPlayerViewModel: Buffer full")
                    self?.isBuffering = false
                }
            }
            .store(in: &cancellables)
        
        // Observe player item status
        playerItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.handlePlayerItemStatus(status)
            }
            .store(in: &cancellables)
        
        // Observe loaded time ranges for progress
        playerItem.publisher(for: \.loadedTimeRanges)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ranges in
                self?.updateLoadingProgress(ranges)
            }
            .store(in: &cancellables)
        
        // Observe playback stalls
        NotificationCenter.default.publisher(for: .AVPlayerItemPlaybackStalled, object: playerItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                debugLog("SimpleVideoPlayerViewModel: Playback stalled - rebuffering")
                self?.isBuffering = true
            }
            .store(in: &cancellables)
        
        // Observe playback errors
        NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                    debugLog("SimpleVideoPlayerViewModel: Playback failed: \(error)")
                    self?.errorMessage = "Playback failed: \(error.localizedDescription)"
                }
            }
            .store(in: &cancellables)
    }
    
    private func handlePlayerItemStatus(_ status: AVPlayerItem.Status) {
        switch status {
        case .readyToPlay:
            debugLog("SimpleVideoPlayerViewModel: Player ready to play")
            isLoading = false
            // Start playback when buffer is likely to keep up
            if playerItem?.isPlaybackLikelyToKeepUp == true {
                player?.play()
            }
        case .failed:
            debugLog("SimpleVideoPlayerViewModel: Player failed")
            isLoading = false
            errorMessage = playerItem?.error?.localizedDescription ?? "Video failed to load"
        case .unknown:
            debugLog("SimpleVideoPlayerViewModel: Player status unknown")
        @unknown default:
            break
        }
    }
    
    private func updateLoadingProgress(_ ranges: [NSValue]) {
        guard let duration = playerItem?.duration,
              duration.isNumeric,
              !duration.seconds.isNaN,
              duration.seconds > 0 else { return }
        
        var totalBuffered: Double = 0
        for value in ranges {
            let range = value.timeRangeValue
            totalBuffered += range.duration.seconds
        }
        
        loadingProgress = min(totalBuffered / duration.seconds, 1.0)
    }
}

// MARK: - Custom Error

extension ImmichError {
    static var videoPlaybackFailed: ImmichError {
        return .clientError(400)
    }
}
