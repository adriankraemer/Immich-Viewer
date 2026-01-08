import Foundation
import SwiftUI
import AVKit
import Combine

// MARK: - SimpleVideoPlayerViewModel

@MainActor
class SimpleVideoPlayerViewModel: ObservableObject {
    // MARK: - Published Properties (View State)
    @Published var player: AVPlayer?
    @Published var isLoading = true
    @Published var isBuffering = false
    @Published var errorMessage: String?
    @Published var loadingProgress: Double = 0.0
    @Published var bufferStatus: String = ""
    @Published var bufferPercentage: Int = 0
    
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
    private var shouldBePlaying = false
    
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
        bufferPercentage = 0
        
        debugLog("SimpleVideoPlayerViewModel: Loading video for asset \(asset.id)")
        
        // Validate asset type
        guard asset.type == .video else {
            debugLog("SimpleVideoPlayerViewModel: Asset is not a video")
            errorMessage = "This asset is not a video"
            isLoading = false
            bufferStatus = ""
            return
        }
        
        do {
            let videoURL = try await assetService.loadVideoURL(asset: asset)
            let headers = authenticationService.getAuthHeaders()
            
            debugLog("SimpleVideoPlayerViewModel: Video URL: \(videoURL)")
            debugLog("SimpleVideoPlayerViewModel: Auth headers count: \(headers.count)")
            
            // Build authenticated URL with query parameters
            let authenticatedURL = addAuthToURL(videoURL, headers: headers)
            debugLog("SimpleVideoPlayerViewModel: Authenticated URL created")
            
            // Create AVURLAsset with authenticated URL
            // Also pass headers as backup for servers that support it
            var options: [String: Any] = [:]
            if !headers.isEmpty {
                options["AVURLAssetHTTPHeaderFieldsKey"] = headers
            }
            
            let urlAsset = AVURLAsset(url: authenticatedURL, options: options)
            
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
            setupLoadingTimeout()
            
        } catch {
            debugLog("SimpleVideoPlayerViewModel: Failed to load video: \(error)")
            handleLoadError(error)
        }
    }
    
    private func addAuthToURL(_ url: URL, headers: [String: String]) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []
        
        if let apiKey = headers["x-api-key"] {
            queryItems.append(URLQueryItem(name: "apiKey", value: apiKey))
            debugLog("SimpleVideoPlayerViewModel: Added API key to URL")
        } else if let bearer = headers["Authorization"]?.replacingOccurrences(of: "Bearer ", with: "") {
            queryItems.append(URLQueryItem(name: "token", value: bearer))
            debugLog("SimpleVideoPlayerViewModel: Added JWT token to URL")
        }
        
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        return components?.url ?? url
    }
    
    private func setupLoadingTimeout() {
        Task {
            try? await Task.sleep(nanoseconds: 20_000_000_000) // 20 seconds
            await MainActor.run {
                if self.isLoading && self.errorMessage == nil {
                    debugLog("SimpleVideoPlayerViewModel: Timeout waiting for player to become ready")
                    
                    // Check player status for diagnostics
                    if let status = self.playerItem?.status {
                        debugLog("SimpleVideoPlayerViewModel: PlayerItem status: \(status.rawValue)")
                    }
                    if let error = self.playerItem?.error {
                        debugLog("SimpleVideoPlayerViewModel: PlayerItem error: \(error)")
                        self.handleLoadError(error)
                    } else {
                        self.errorMessage = "Video is taking too long to load. Please check your connection and try again."
                        self.isLoading = false
                        self.bufferStatus = ""
                    }
                }
            }
        }
    }
    
    /// Retries loading the video
    func retry() async {
        cleanup()
        await loadVideoIfNeeded(force: true)
    }
    
    /// Retries with a different authentication method (kept for UI compatibility)
    func retryWithFallback() async {
        await retry()
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
        bufferPercentage = 0
    }
    
    // MARK: - Error Handling
    
    private func handleLoadError(_ error: Error) {
        isLoading = false
        bufferStatus = ""
        
        let nsError = error as NSError
        debugLog("SimpleVideoPlayerViewModel: Error domain: \(nsError.domain), code: \(nsError.code)")
        
        // Map error to user-friendly message
        errorMessage = mapErrorToMessage(nsError)
    }
    
    private func mapErrorToMessage(_ error: NSError) -> String {
        // URL errors
        if error.domain == NSURLErrorDomain {
            switch error.code {
            case NSURLErrorTimedOut:
                return "Connection timed out. Please check your network."
            case NSURLErrorNotConnectedToInternet:
                return "No internet connection."
            case NSURLErrorNetworkConnectionLost:
                return "Network connection lost."
            case NSURLErrorCannotFindHost:
                return "Cannot reach server. Please check the server URL."
            case NSURLErrorSecureConnectionFailed:
                return "Secure connection failed. Please check server configuration."
            case NSURLErrorUserAuthenticationRequired:
                return "Authentication required. Please sign in again."
            default:
                return "Network error: \(error.localizedDescription)"
            }
        }
        
        // AVFoundation errors
        if error.domain == AVFoundationErrorDomain {
            switch error.code {
            case AVError.Code.unknown.rawValue:
                return "Unknown playback error. Please try again."
            case AVError.Code.serverIncorrectlyConfigured.rawValue:
                return "Server configuration error. The video format may not be supported."
            case AVError.Code.noLongerPlayable.rawValue:
                return "Video is no longer available for playback."
            case AVError.Code.mediaServicesWereReset.rawValue:
                return "Media services were reset. Please try again."
            case AVError.Code.decodeFailed.rawValue:
                return "Failed to decode video. The format may not be supported."
            default:
                return "Playback error: \(error.localizedDescription)"
            }
        }
        
        // VideoPlaybackError
        if let playbackError = error as? VideoPlaybackError {
            return playbackError.localizedDescription
        }
        
        return error.localizedDescription
    }
    
    // MARK: - Player Configuration
    
    private func configurePlayer(_ player: AVPlayer) {
        // Enable automatic waiting for smoother playback
        // This lets AVPlayer handle buffering intelligently
        player.automaticallyWaitsToMinimizeStalling = true
        
        // Prevent display from sleeping during video playback
        player.preventsDisplaySleepDuringVideoPlayback = true
        
        debugLog("SimpleVideoPlayerViewModel: Player configured with automatic stall handling")
    }
    
    private func configureBufferSettings(_ playerItem: AVPlayerItem) {
        // Set preferred forward buffer duration (in seconds)
        // 10 seconds provides good balance between startup time and smooth playback
        playerItem.preferredForwardBufferDuration = 10
        
        // Configure for network streaming - continue buffering even when paused
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        
        // Set preferred peak bit rate (0 = no limit, let it adapt)
        playerItem.preferredPeakBitRate = 0
        
        // Set preferred maximum resolution (0 = no limit)
        playerItem.preferredMaximumResolution = .zero
        
        debugLog("SimpleVideoPlayerViewModel: Buffer configured - 10s forward buffer")
    }
    
    // MARK: - Player Observers
    
    private func setupPlayerRateObserver(_ player: AVPlayer) {
        player.publisher(for: \.rate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rate in
                guard let self = self else { return }
                
                if rate == 0 && self.shouldBePlaying && !self.isLoading {
                    debugLog("SimpleVideoPlayerViewModel: Rate dropped to 0, checking if recovery needed")
                    
                    if let playerItem = self.playerItem,
                       playerItem.status == .readyToPlay {
                        
                        if !playerItem.isPlaybackBufferEmpty {
                            self.isBuffering = true
                            self.bufferStatus = "Buffering..."
                            
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 500_000_000)
                                self.attemptPlaybackRecovery()
                            }
                        }
                    }
                } else if rate > 0 && self.shouldBePlaying {
                    self.isBuffering = false
                    self.bufferStatus = ""
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupTimeObserver(_ player: AVPlayer) {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.updateBufferStatusDisplay()
                self?.ensurePlaybackContinues()
            }
        }
    }
    
    private func ensurePlaybackContinues() {
        guard shouldBePlaying,
              let player = player,
              let playerItem = playerItem,
              playerItem.status == .readyToPlay else { return }
        
        if player.rate == 0 {
            if playerItem.isPlaybackLikelyToKeepUp || playerItem.isPlaybackBufferFull {
                debugLog("SimpleVideoPlayerViewModel: Auto-resuming stalled playback")
                isBuffering = false
                bufferStatus = ""
                player.play()
            }
        }
    }
    
    private func attemptPlaybackRecovery() {
        guard shouldBePlaying,
              let player = player,
              let playerItem = playerItem,
              playerItem.status == .readyToPlay else { return }
        
        if player.rate == 0 {
            debugLog("SimpleVideoPlayerViewModel: Attempting playback recovery")
            
            if playerItem.isPlaybackLikelyToKeepUp || !playerItem.isPlaybackBufferEmpty {
                player.play()
                
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
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
        
        var totalBuffered: Double = 0
        for value in playerItem.loadedTimeRanges {
            let range = value.timeRangeValue
            totalBuffered += range.duration.seconds
        }
        
        let percentBuffered = Int((totalBuffered / duration) * 100)
        bufferPercentage = percentBuffered
        
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
                
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000)
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
                    self?.handleLoadError(error)
                }
            }
            .store(in: &cancellables)
        
        // Observe when playback reaches the end
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                debugLog("SimpleVideoPlayerViewModel: Playback completed")
                self?.bufferStatus = ""
                self?.shouldBePlaying = false
            }
            .store(in: &cancellables)
        
        // Observe for new access logs (indicates playback started successfully)
        NotificationCenter.default.publisher(for: .AVPlayerItemNewAccessLogEntry, object: playerItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if let accessLog = self.playerItem?.accessLog(),
                   let event = accessLog.events.last {
                    debugLog("SimpleVideoPlayerViewModel: Access log - bitrate: \(event.indicatedBitrate), segments: \(event.numberOfMediaRequests)")
                }
            }
            .store(in: &cancellables)
        
        // Observe for new error log entries
        NotificationCenter.default.publisher(for: .AVPlayerItemNewErrorLogEntry, object: playerItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if let errorLog = self.playerItem?.errorLog(),
                   let event = errorLog.events.last {
                    debugLog("SimpleVideoPlayerViewModel: Error log - domain: \(event.errorDomain), code: \(event.errorStatusCode), comment: \(event.errorComment ?? "none")")
                }
            }
            .store(in: &cancellables)
    }
    
    private func handlePlayerItemStatus(_ status: AVPlayerItem.Status) {
        switch status {
        case .readyToPlay:
            debugLog("SimpleVideoPlayerViewModel: Player ready to play")
            isLoading = false
            bufferStatus = ""
            
            // Start playback when ready
            debugLog("SimpleVideoPlayerViewModel: Starting playback")
            shouldBePlaying = true
            player?.play()
            
        case .failed:
            debugLog("SimpleVideoPlayerViewModel: Player failed")
            
            if let error = playerItem?.error {
                handleLoadError(error)
            } else {
                errorMessage = "Video failed to load"
                isLoading = false
                bufferStatus = ""
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
        bufferPercentage = Int(loadingProgress * 100)
        
        if isLoading || isBuffering {
            let bufferedSeconds = Int(totalBuffered)
            let totalSeconds = Int(duration.seconds)
            bufferStatus = "Buffered: \(bufferedSeconds)s / \(totalSeconds)s"
        }
    }
}

// MARK: - Video Playback Error

enum VideoPlaybackError: Error, LocalizedError {
    case invalidURL
    case authenticationFailed
    case notAVideo
    case serverError(Int)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid video URL"
        case .authenticationFailed:
            return "Authentication failed. Please sign in again."
        case .notAVideo:
            return "This asset is not a video"
        case .serverError(let code):
            return "Server error (HTTP \(code))"
        case .unknown:
            return "Unknown error occurred"
        }
    }
}

// MARK: - ImmichError Extension

extension ImmichError {
    static var videoPlaybackFailed: ImmichError {
        return .clientError(400)
    }
}
