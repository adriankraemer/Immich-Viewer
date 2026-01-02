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
    @Published var bufferStatus: String = ""
    
    // MARK: - Dependencies
    private let assetService: AssetService
    private let authenticationService: AuthenticationService
    
    // MARK: - Configuration
    let asset: ImmichAsset
    
    // MARK: - Internal State
    private var hasAttemptedLoad = false
    private var playerItem: AVPlayerItem?
    private var cancellables = Set<AnyCancellable>()
    private var timeObserver: Any?
    private var shouldBePlaying = false  // Track intended playback state
    
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
        bufferStatus = "Initializing..."
        
        debugLog("SimpleVideoPlayerViewModel: Loading video for asset \(asset.id)")
        
        do {
            let videoURL = try await assetService.loadVideoURL(asset: asset)
            let headers = authenticationService.getAuthHeaders()
            
            debugLog("SimpleVideoPlayerViewModel: Video URL: \(videoURL)")
            debugLog("SimpleVideoPlayerViewModel: Auth headers: \(headers)")
            
            // Build URL with authentication token as query parameter (most reliable for AVPlayer)
            var finalURL = videoURL
            if let apiKey = headers["x-api-key"] {
                // API key auth - add as query parameter
                var components = URLComponents(url: videoURL, resolvingAgainstBaseURL: false)
                var queryItems = components?.queryItems ?? []
                queryItems.append(URLQueryItem(name: "apiKey", value: apiKey))
                components?.queryItems = queryItems
                if let urlWithKey = components?.url {
                    finalURL = urlWithKey
                    debugLog("SimpleVideoPlayerViewModel: Using API key in URL")
                }
            } else if let bearer = headers["Authorization"]?.replacingOccurrences(of: "Bearer ", with: "") {
                // JWT auth - add as query parameter  
                var components = URLComponents(url: videoURL, resolvingAgainstBaseURL: false)
                var queryItems = components?.queryItems ?? []
                queryItems.append(URLQueryItem(name: "token", value: bearer))
                components?.queryItems = queryItems
                if let urlWithToken = components?.url {
                    finalURL = urlWithToken
                    debugLog("SimpleVideoPlayerViewModel: Using JWT token in URL")
                }
            }
            
            // Create AVURLAsset with the authenticated URL
            // Also pass headers as backup for servers that support it
            var options: [String: Any] = [:]
            if !headers.isEmpty {
                options["AVURLAssetHTTPHeaderFieldsKey"] = headers
            }
            
            let urlAsset = AVURLAsset(url: finalURL, options: options)
            
            debugLog("SimpleVideoPlayerViewModel: Created AVURLAsset with authenticated URL")
            
            bufferStatus = "Loading video..."
            
            // Create player item
            let playerItem = AVPlayerItem(asset: urlAsset)
            self.playerItem = playerItem
            
            // Configure buffer settings for smoother playback
            configureBufferSettings(playerItem)
            
            // Set up observers BEFORE creating player
            setupPlayerItemObservers(playerItem)
            
            bufferStatus = "Preparing player..."
            
            // Create and configure player with optimized settings
            let player = AVPlayer(playerItem: playerItem)
            configurePlayer(player)
            
            debugLog("SimpleVideoPlayerViewModel: Player created, waiting for ready state")
            self.player = player
            
            // Set up periodic time observer for buffer monitoring
            setupTimeObserver(player)
            
            // Observe player rate changes to detect unexpected stops
            setupPlayerRateObserver(player)
            
            // Add a timeout to detect if player never becomes ready
            Task {
                try? await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
                await MainActor.run {
                    if self.isLoading && self.errorMessage == nil {
                        debugLog("SimpleVideoPlayerViewModel: Timeout waiting for player to become ready")
                        // Check player status
                        if let status = self.playerItem?.status {
                            debugLog("SimpleVideoPlayerViewModel: PlayerItem status: \(status.rawValue)")
                        }
                        if let error = self.playerItem?.error {
                            debugLog("SimpleVideoPlayerViewModel: PlayerItem error: \(error)")
                            self.errorMessage = error.localizedDescription
                        } else {
                            self.errorMessage = "Video is taking too long to load. Please try again."
                        }
                        self.isLoading = false
                        self.bufferStatus = ""
                    }
                }
            }
            
        } catch {
            debugLog("SimpleVideoPlayerViewModel: Failed to load video: \(error)")
            self.errorMessage = error.localizedDescription
            self.isLoading = false
            self.bufferStatus = ""
        }
    }
    
    /// Retries loading the video
    func retry() async {
        cleanup()
        await loadVideoIfNeeded(force: true)
    }
    
    /// Starts playback
    func play() {
        shouldBePlaying = true
        player?.play()
    }
    
    /// Pauses playback
    func pause() {
        shouldBePlaying = false
        player?.pause()
    }
    
    /// Seeks to a specific time (useful for resuming)
    func seek(to time: CMTime, completion: ((Bool) -> Void)? = nil) {
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
            completion?(finished)
        }
    }
    
    /// Cleans up the player
    func cleanup() {
        debugLog("SimpleVideoPlayerViewModel: Cleaning up player")
        
        // Mark that we don't want playback anymore
        shouldBePlaying = false
        
        // Cancel all subscriptions
        cancellables.removeAll()
        
        // Remove time observer
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        // Clean up player
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        playerItem = nil
        hasAttemptedLoad = false
        bufferStatus = ""
    }
    
    // MARK: - Private Methods
    
    private func configurePlayer(_ player: AVPlayer) {
        // Disable automatic waiting - we'll handle stalling ourselves
        // This allows the player to continue even with lower buffer levels
        player.automaticallyWaitsToMinimizeStalling = false
        
        // Prevent display from sleeping during video playback
        player.preventsDisplaySleepDuringVideoPlayback = true
        
        debugLog("SimpleVideoPlayerViewModel: Player configured with manual stall handling")
    }
    
    private func configureBufferSettings(_ playerItem: AVPlayerItem) {
        // Set preferred buffer duration (in seconds)
        // Use 0 to let AVPlayer manage buffer size automatically based on network conditions
        // This allows it to buffer as much as it can without artificial limits
        playerItem.preferredForwardBufferDuration = 0
        
        // Configure for network streaming - continue buffering even when paused
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        
        // Set preferred peak bit rate (0 = no limit, let it adapt)
        playerItem.preferredPeakBitRate = 0
        
        // Set preferred maximum resolution (0 = no limit)
        playerItem.preferredMaximumResolution = .zero
        
        debugLog("SimpleVideoPlayerViewModel: Buffer configured - automatic buffer duration")
    }
    
    private func setupPlayerRateObserver(_ player: AVPlayer) {
        // Observe rate changes to detect when playback stops unexpectedly
        player.publisher(for: \.rate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rate in
                guard let self = self else { return }
                
                // If rate dropped to 0 but we should be playing, try to recover
                if rate == 0 && self.shouldBePlaying && !self.isLoading {
                    debugLog("SimpleVideoPlayerViewModel: Rate dropped to 0, checking if recovery needed")
                    
                    // Check if this is due to buffering or an actual stop
                    if let playerItem = self.playerItem,
                       playerItem.status == .readyToPlay {
                        
                        // If buffer is not empty, this might be a temporary stall
                        if !playerItem.isPlaybackBufferEmpty {
                            self.isBuffering = true
                            self.bufferStatus = "Buffering..."
                            
                            // Schedule recovery attempt
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                                self.attemptPlaybackRecovery()
                            }
                        }
                    }
                } else if rate > 0 && self.shouldBePlaying {
                    // Playback resumed successfully
                    self.isBuffering = false
                    self.bufferStatus = ""
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupTimeObserver(_ player: AVPlayer) {
        // Monitor buffer status every 0.5 seconds
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.updateBufferStatusDisplay()
                self?.ensurePlaybackContinues()
            }
        }
    }
    
    /// Ensures playback continues if it should be playing and conditions are met
    private func ensurePlaybackContinues() {
        guard shouldBePlaying,
              let player = player,
              let playerItem = playerItem,
              playerItem.status == .readyToPlay else { return }
        
        // Check if player has stalled (rate is 0 but we want it playing)
        if player.rate == 0 {
            // Check if we have enough buffer to resume
            if playerItem.isPlaybackLikelyToKeepUp || playerItem.isPlaybackBufferFull {
                debugLog("SimpleVideoPlayerViewModel: Auto-resuming stalled playback")
                isBuffering = false
                bufferStatus = ""
                player.play()
            } else if !playerItem.isPlaybackBufferEmpty {
                // We have some buffer, try to resume anyway
                // AVPlayer will handle re-buffering if needed
                debugLog("SimpleVideoPlayerViewModel: Attempting to resume with partial buffer")
                player.play()
            }
        }
    }
    
    /// Attempts to recover playback after a stall
    private func attemptPlaybackRecovery() {
        guard shouldBePlaying,
              let player = player,
              let playerItem = playerItem,
              playerItem.status == .readyToPlay else { return }
        
        // Try to resume playback
        if player.rate == 0 {
            debugLog("SimpleVideoPlayerViewModel: Attempting playback recovery")
            
            // If buffer has any data, try to play
            if playerItem.isPlaybackLikelyToKeepUp || !playerItem.isPlaybackBufferEmpty {
                player.play()
                
                // Schedule another check to ensure playback resumed
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    if self.shouldBePlaying && self.player?.rate == 0 {
                        debugLog("SimpleVideoPlayerViewModel: Playback still stalled, retrying")
                        self.player?.play()
                    }
                }
            }
        }
    }
    
    private func updateBufferStatusDisplay() {
        guard let playerItem = playerItem,
              let duration = playerItem.duration.seconds.isNaN ? nil : playerItem.duration.seconds,
              duration > 0 else { return }
        
        // Calculate total buffered time
        var totalBuffered: Double = 0
        for value in playerItem.loadedTimeRanges {
            let range = value.timeRangeValue
            totalBuffered += range.duration.seconds
        }
        
        let percentBuffered = Int((totalBuffered / duration) * 100)
        
        if isBuffering {
            bufferStatus = "Buffering: \(percentBuffered)%"
        }
    }
    
    private func setupPlayerItemObservers(_ playerItem: AVPlayerItem) {
        // Observe playback buffer status
        playerItem.publisher(for: \.isPlaybackBufferEmpty)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEmpty in
                guard let self = self else { return }
                if isEmpty && !self.isLoading && self.shouldBePlaying {
                    self.isBuffering = true
                    self.bufferStatus = "Buffering..."
                    debugLog("SimpleVideoPlayerViewModel: Buffer empty, waiting for data")
                }
            }
            .store(in: &cancellables)
        
        // Observe when buffer has enough data to resume
        playerItem.publisher(for: \.isPlaybackLikelyToKeepUp)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLikelyToKeepUp in
                guard let self = self else { return }
                if isLikelyToKeepUp && self.shouldBePlaying {
                    self.isBuffering = false
                    self.bufferStatus = ""
                    // Resume playback if we should be playing
                    if self.player?.currentItem?.status == .readyToPlay {
                        debugLog("SimpleVideoPlayerViewModel: Buffer ready, resuming playback")
                        self.player?.play()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Observe buffer full status
        playerItem.publisher(for: \.isPlaybackBufferFull)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isFull in
                guard let self = self else { return }
                if isFull && self.shouldBePlaying {
                    self.isBuffering = false
                    self.bufferStatus = ""
                    // Resume playback if buffer is full
                    if self.player?.currentItem?.status == .readyToPlay {
                        debugLog("SimpleVideoPlayerViewModel: Buffer full, resuming playback")
                        self.player?.play()
                    }
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
                guard let self = self else { return }
                debugLog("SimpleVideoPlayerViewModel: Playback stalled, attempting recovery")
                self.isBuffering = true
                self.bufferStatus = "Buffering..."
                
                // Schedule a recovery attempt after a short delay
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    self.attemptPlaybackRecovery()
                }
            }
            .store(in: &cancellables)
        
        // Observe playback errors
        NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                    debugLog("SimpleVideoPlayerViewModel: Playback failed: \(error)")
                    self?.errorMessage = "Playback failed: \(error.localizedDescription)"
                    self?.bufferStatus = ""
                }
            }
            .store(in: &cancellables)
        
        // Observe when playback reaches the end
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                debugLog("SimpleVideoPlayerViewModel: Playback completed")
                self?.bufferStatus = ""
            }
            .store(in: &cancellables)
    }
    
    private func handlePlayerItemStatus(_ status: AVPlayerItem.Status) {
        switch status {
        case .readyToPlay:
            debugLog("SimpleVideoPlayerViewModel: Player ready to play")
            isLoading = false
            bufferStatus = ""
            
            // Start playback immediately when ready
            debugLog("SimpleVideoPlayerViewModel: Starting playback")
            shouldBePlaying = true
            player?.play()
            
        case .failed:
            debugLog("SimpleVideoPlayerViewModel: Player failed")
            isLoading = false
            bufferStatus = ""
            
            // Provide more detailed error message
            if let error = playerItem?.error {
                let nsError = error as NSError
                debugLog("SimpleVideoPlayerViewModel: Error domain: \(nsError.domain), code: \(nsError.code)")
                
                if nsError.domain == NSURLErrorDomain {
                    switch nsError.code {
                    case NSURLErrorTimedOut:
                        errorMessage = "Connection timed out. Please check your network."
                    case NSURLErrorNotConnectedToInternet:
                        errorMessage = "No internet connection."
                    case NSURLErrorNetworkConnectionLost:
                        errorMessage = "Network connection lost."
                    default:
                        errorMessage = "Network error: \(error.localizedDescription)"
                    }
                } else {
                    errorMessage = error.localizedDescription
                }
            } else {
                errorMessage = "Video failed to load"
            }
        case .unknown:
            debugLog("SimpleVideoPlayerViewModel: Player status unknown")
            bufferStatus = "Preparing..."
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
        
        // Update buffer status with more detail during initial load
        if isLoading || isBuffering {
            let bufferedSeconds = Int(totalBuffered)
            let totalSeconds = Int(duration.seconds)
            bufferStatus = "Buffered: \(bufferedSeconds)s / \(totalSeconds)s"
        }
    }
}

// MARK: - Custom Error

extension ImmichError {
    static var videoPlaybackFailed: ImmichError {
        return .clientError(400)
    }
}
