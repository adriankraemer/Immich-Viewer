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
    private var isWaitingForInitialBuffer = false
    private var hasTriedFallbackEndpoint = false
    private var currentVideoURL: URL?
    private var lastBufferAmount: TimeInterval = 0
    private var bufferStallCount: Int = 0
    private var bufferStallCheckTask: Task<Void, Never>?
    
    // MARK: - Buffer Configuration Constants
    /// Forward buffer duration in seconds - larger buffer for remote streaming
    private let forwardBufferDuration: TimeInterval = 30
    /// Minimum seconds of buffer required before starting playback
    private let minimumBufferBeforePlayback: TimeInterval = 5
    /// Minimum seconds of buffer required before resuming after a stall
    private let minimumBufferBeforeResume: TimeInterval = 10
    /// Number of stall checks before considering buffer truly stalled
    private let maxBufferStallChecks: Int = 5
    
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
        
        // Try the playback endpoint first, then fall back to original if needed
        await loadVideoFromEndpoint(useOriginal: false)
    }
    
    /// Loads video from specified endpoint (playback or original)
    private func loadVideoFromEndpoint(useOriginal: Bool) async {
        do {
            let videoURL: URL
            if useOriginal {
                debugLog("SimpleVideoPlayerViewModel: Trying original video endpoint")
                bufferStatus = "Trying original video..."
                videoURL = try await assetService.loadOriginalVideoURL(asset: asset)
            } else {
                debugLog("SimpleVideoPlayerViewModel: Trying playback video endpoint")
                videoURL = try await assetService.loadVideoURL(asset: asset)
            }
            
            currentVideoURL = videoURL
            let headers = authenticationService.getAuthHeaders()
            
            debugLog("SimpleVideoPlayerViewModel: Video URL: \(videoURL)")
            debugLog("SimpleVideoPlayerViewModel: Auth headers count: \(headers.count)")
            
            // Build authenticated URL with query parameters
            let authenticatedURL = addAuthToURL(videoURL, headers: headers)
            debugLog("SimpleVideoPlayerViewModel: Authenticated URL created")
            
            // Create AVURLAsset with options optimized for streaming
            var options: [String: Any] = [
                // Don't require precise duration - allows faster initial loading
                AVURLAssetPreferPreciseDurationAndTimingKey: false
            ]
            if !headers.isEmpty {
                options["AVURLAssetHTTPHeaderFieldsKey"] = headers
            }
            
            let urlAsset = AVURLAsset(url: authenticatedURL, options: options)
            
            bufferStatus = "Verifying video..."
            
            // Verify the asset is playable before creating player
            // This gives us better error information if the connection fails
            do {
                let isPlayable = try await urlAsset.load(.isPlayable)
                let duration = try await urlAsset.load(.duration)
                
                guard isPlayable else {
                    debugLog("SimpleVideoPlayerViewModel: Asset is not playable")
                    throw VideoPlaybackError.unknown
                }
                
                debugLog("SimpleVideoPlayerViewModel: Asset verified - playable: \(isPlayable), duration: \(duration.seconds)s")
            } catch {
                debugLog("SimpleVideoPlayerViewModel: Failed to verify asset: \(error)")
                
                // If this was the playback endpoint and we haven't tried the original yet, try it
                if !useOriginal && !hasTriedFallbackEndpoint {
                    debugLog("SimpleVideoPlayerViewModel: Falling back to original endpoint")
                    hasTriedFallbackEndpoint = true
                    await loadVideoFromEndpoint(useOriginal: true)
                    return
                }
                
                throw error
            }
            
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
            
            // If this was the playback endpoint and we haven't tried the original yet, try it
            if !useOriginal && !hasTriedFallbackEndpoint {
                debugLog("SimpleVideoPlayerViewModel: Falling back to original endpoint after error")
                hasTriedFallbackEndpoint = true
                await loadVideoFromEndpoint(useOriginal: true)
                return
            }
            
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
            try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds for initial connection
            await MainActor.run {
                // Don't trigger timeout if:
                // 1. We're already done loading
                // 2. We already have an error
                // 3. We're successfully building the initial buffer (player is ready, just waiting for buffer)
                // 4. Playback has already started
                
                let isSuccessfullyBuffering = self.isWaitingForInitialBuffer && self.playerItem?.status == .readyToPlay
                let hasStartedPlayback = self.shouldBePlaying && self.player?.rate ?? 0 > 0
                
                if self.isLoading && self.errorMessage == nil && !isSuccessfullyBuffering && !hasStartedPlayback {
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
                } else if isSuccessfullyBuffering {
                    debugLog("SimpleVideoPlayerViewModel: Timeout skipped - successfully building initial buffer")
                }
            }
        }
    }
    
    /// Retries loading the video
    func retry() async {
        cleanup()
        await loadVideoIfNeeded(force: true)
    }
    
    /// Retries with the original video endpoint (fallback)
    func retryWithFallback() async {
        cleanup()
        hasAttemptedLoad = true
        isLoading = true
        isBuffering = false
        errorMessage = nil
        loadingProgress = 0.0
        bufferStatus = "Trying original video..."
        bufferPercentage = 0
        hasTriedFallbackEndpoint = true
        
        // Skip playback endpoint and go directly to original
        await loadVideoFromEndpoint(useOriginal: true)
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
        
        // Cancel stall detection task
        bufferStallCheckTask?.cancel()
        bufferStallCheckTask = nil
        
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
        hasTriedFallbackEndpoint = false
        isWaitingForInitialBuffer = false
        currentVideoURL = nil
        lastBufferAmount = 0
        bufferStallCount = 0
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
        // 30 seconds provides larger runway for remote streaming with variable network speeds
        playerItem.preferredForwardBufferDuration = forwardBufferDuration
        
        // Configure for network streaming - continue buffering even when paused
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        
        // Set preferred peak bit rate (0 = no limit, let it adapt)
        playerItem.preferredPeakBitRate = 0
        
        // Set preferred maximum resolution (0 = no limit)
        playerItem.preferredMaximumResolution = .zero
        
        debugLog("SimpleVideoPlayerViewModel: Buffer configured - \(Int(forwardBufferDuration))s forward buffer")
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
              playerItem.status == .readyToPlay,
              !isWaitingForInitialBuffer else { return }
        
        if player.rate == 0 && isBuffering {
            let currentBufferSeconds = getCurrentBufferSeconds()
            
            // Only resume if we have sufficient buffer or buffer is full
            if currentBufferSeconds >= minimumBufferBeforeResume || playerItem.isPlaybackBufferFull {
                debugLog("SimpleVideoPlayerViewModel: Auto-resuming with \(Int(currentBufferSeconds))s buffer")
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
            let currentBufferSeconds = getCurrentBufferSeconds()
            debugLog("SimpleVideoPlayerViewModel: Attempting playback recovery - buffer: \(Int(currentBufferSeconds))s")
            
            // Wait for sufficient buffer before resuming to prevent rapid stall cycles
            if currentBufferSeconds >= minimumBufferBeforeResume {
                debugLog("SimpleVideoPlayerViewModel: Buffer sufficient (\(Int(currentBufferSeconds))s >= \(Int(minimumBufferBeforeResume))s), resuming")
                isBuffering = false
                bufferStatus = ""
                player.play()
            } else if playerItem.isPlaybackBufferFull {
                // Buffer is full, resume regardless
                debugLog("SimpleVideoPlayerViewModel: Buffer full, resuming")
                isBuffering = false
                bufferStatus = ""
                player.play()
            } else {
                // Not enough buffer yet, update status and wait
                bufferStatus = "Buffering: \(Int(currentBufferSeconds))s / \(Int(minimumBufferBeforeResume))s needed"
                debugLog("SimpleVideoPlayerViewModel: Waiting for more buffer before resuming")
                
                // Schedule another check
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // Check again in 1 second
                    if self.shouldBePlaying && self.player?.rate == 0 && !self.isLoading {
                        self.attemptPlaybackRecovery()
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
            let currentBufferSeconds = getCurrentBufferSeconds()
            let neededSeconds = Int(minimumBufferBeforeResume)
            bufferStatus = "Buffering: \(Int(currentBufferSeconds))s / \(neededSeconds)s"
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
            
            guard let playerItem = playerItem else { return }
            
            let currentBufferSeconds = getCurrentBufferSeconds()
            
            // Start playback if:
            // 1. AVPlayer thinks it can keep up (it knows the bitrate and network speed), OR
            // 2. We have our minimum buffer amount
            // Trust AVPlayer's isPlaybackLikelyToKeepUp - it factors in bitrate and network conditions
            if playerItem.isPlaybackLikelyToKeepUp || currentBufferSeconds >= minimumBufferBeforePlayback {
                isLoading = false
                isWaitingForInitialBuffer = false
                bufferStatus = ""
                bufferStallCheckTask?.cancel()
                bufferStallCheckTask = nil
                debugLog("SimpleVideoPlayerViewModel: Starting playback - buffer: \(String(format: "%.1f", currentBufferSeconds))s, likelyToKeepUp: \(playerItem.isPlaybackLikelyToKeepUp)")
                shouldBePlaying = true
                player?.play()
            } else {
                // Wait for more buffer before starting
                isWaitingForInitialBuffer = true
                bufferStatus = "Building buffer: \(Int(currentBufferSeconds))s"
                debugLog("SimpleVideoPlayerViewModel: Waiting for initial buffer - have \(Int(currentBufferSeconds))s, likelyToKeepUp: \(playerItem.isPlaybackLikelyToKeepUp)")
            }
            
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
    
    /// Returns the current amount of buffered content ahead of playback position in seconds
    private func getCurrentBufferSeconds() -> TimeInterval {
        guard let playerItem = playerItem else { return 0 }
        
        let currentTime = playerItem.currentTime()
        
        for value in playerItem.loadedTimeRanges {
            let range = value.timeRangeValue
            let rangeStart = range.start
            let rangeEnd = CMTimeAdd(range.start, range.duration)
            
            // Check if current time is within this range
            if CMTimeCompare(currentTime, rangeStart) >= 0 && CMTimeCompare(currentTime, rangeEnd) <= 0 {
                // Return seconds from current position to end of this buffered range
                let bufferedAhead = CMTimeSubtract(rangeEnd, currentTime)
                return bufferedAhead.seconds
            }
        }
        
        // If we're at the start (time 0), return the first range's duration
        if currentTime.seconds == 0, let firstRange = playerItem.loadedTimeRanges.first {
            return firstRange.timeRangeValue.duration.seconds
        }
        
        return 0
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
        
        // Check if we're waiting for initial buffer and now have enough
        if isWaitingForInitialBuffer {
            let currentBufferSeconds = getCurrentBufferSeconds()
            
            // Check if buffer is growing
            if currentBufferSeconds > lastBufferAmount + 0.1 {
                // Buffer is growing, reset stall counter
                bufferStallCount = 0
                lastBufferAmount = currentBufferSeconds
                debugLog("SimpleVideoPlayerViewModel: Buffer growing - \(String(format: "%.1f", currentBufferSeconds))s")
            }
            
            // Start playback if AVPlayer thinks it can keep up OR we have minimum buffer
            let likelyToKeepUp = playerItem?.isPlaybackLikelyToKeepUp ?? false
            if likelyToKeepUp || currentBufferSeconds >= minimumBufferBeforePlayback {
                debugLog("SimpleVideoPlayerViewModel: Initial buffer ready - buffer: \(String(format: "%.1f", currentBufferSeconds))s, likelyToKeepUp: \(likelyToKeepUp)")
                isWaitingForInitialBuffer = false
                isLoading = false
                bufferStatus = ""
                bufferStallCheckTask?.cancel()
                bufferStallCheckTask = nil
                shouldBePlaying = true
                player?.play()
            } else {
                bufferStatus = "Building buffer: \(Int(currentBufferSeconds))s"
                
                // Start stall detection if not already running
                startBufferStallDetection()
            }
        } else if isLoading || isBuffering {
            let bufferedSeconds = Int(totalBuffered)
            let totalSeconds = Int(duration.seconds)
            bufferStatus = "Buffered: \(bufferedSeconds)s / \(totalSeconds)s"
        }
    }
    
    /// Monitors buffer progress and detects if it has stalled
    private func startBufferStallDetection() {
        // Don't start if already running
        guard bufferStallCheckTask == nil else { return }
        
        bufferStallCheckTask = Task { @MainActor in
            while !Task.isCancelled && isWaitingForInitialBuffer {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // Check every 2 seconds
                
                guard !Task.isCancelled && isWaitingForInitialBuffer else { break }
                
                let currentBufferSeconds = getCurrentBufferSeconds()
                
                // Check if buffer hasn't grown
                if currentBufferSeconds <= lastBufferAmount + 0.1 {
                    bufferStallCount += 1
                    debugLog("SimpleVideoPlayerViewModel: Buffer stall detected (\(bufferStallCount)/\(maxBufferStallChecks)) - stuck at \(String(format: "%.1f", currentBufferSeconds))s")
                    
                    // Log diagnostic info
                    logBufferDiagnostics()
                    
                    if bufferStallCount >= maxBufferStallChecks {
                        debugLog("SimpleVideoPlayerViewModel: Buffer stalled for too long, attempting fallback")
                        
                        // If we haven't tried the fallback endpoint yet, try it
                        if !hasTriedFallbackEndpoint {
                            hasTriedFallbackEndpoint = true
                            bufferStallCheckTask?.cancel()
                            bufferStallCheckTask = nil
                            
                            // Clean up current player and try fallback
                            cleanupCurrentPlayer()
                            await loadVideoFromEndpoint(useOriginal: true)
                            return
                        } else {
                            // Already tried fallback, show error
                            errorMessage = "Video streaming stalled. The server may not support streaming this video format."
                            isLoading = false
                            isWaitingForInitialBuffer = false
                            bufferStatus = ""
                            bufferStallCheckTask?.cancel()
                            bufferStallCheckTask = nil
                            return
                        }
                    }
                } else {
                    // Buffer is growing, reset counter
                    bufferStallCount = 0
                    lastBufferAmount = currentBufferSeconds
                }
            }
            
            bufferStallCheckTask = nil
        }
    }
    
    /// Logs diagnostic information about the current buffer state
    private func logBufferDiagnostics() {
        guard let playerItem = playerItem else { return }
        
        debugLog("SimpleVideoPlayerViewModel: === Buffer Diagnostics ===")
        debugLog("  Status: \(playerItem.status.rawValue)")
        debugLog("  isPlaybackBufferEmpty: \(playerItem.isPlaybackBufferEmpty)")
        debugLog("  isPlaybackBufferFull: \(playerItem.isPlaybackBufferFull)")
        debugLog("  isPlaybackLikelyToKeepUp: \(playerItem.isPlaybackLikelyToKeepUp)")
        
        if let duration = playerItem.duration.seconds.isNaN ? nil : playerItem.duration.seconds {
            debugLog("  Duration: \(String(format: "%.1f", duration))s")
        }
        
        debugLog("  Loaded ranges: \(playerItem.loadedTimeRanges.count)")
        for (index, range) in playerItem.loadedTimeRanges.enumerated() {
            let timeRange = range.timeRangeValue
            debugLog("    Range \(index): \(String(format: "%.1f", timeRange.start.seconds))s - \(String(format: "%.1f", (timeRange.start + timeRange.duration).seconds))s")
        }
        
        if let errorLog = playerItem.errorLog(), let lastError = errorLog.events.last {
            debugLog("  Last error: domain=\(lastError.errorDomain), code=\(lastError.errorStatusCode), comment=\(lastError.errorComment ?? "none")")
        }
        
        if let accessLog = playerItem.accessLog(), let lastAccess = accessLog.events.last {
            debugLog("  Last access: bitrate=\(lastAccess.indicatedBitrate), requests=\(lastAccess.numberOfMediaRequests)")
        }
        
        debugLog("SimpleVideoPlayerViewModel: === End Diagnostics ===")
    }
    
    /// Cleans up the current player without resetting all state
    private func cleanupCurrentPlayer() {
        debugLog("SimpleVideoPlayerViewModel: Cleaning up current player for retry")
        
        // Cancel stall detection
        bufferStallCheckTask?.cancel()
        bufferStallCheckTask = nil
        
        // Cancel subscriptions
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
        
        // Reset buffer tracking
        lastBufferAmount = 0
        bufferStallCount = 0
        isWaitingForInitialBuffer = false
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
