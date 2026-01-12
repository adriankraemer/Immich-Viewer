import Foundation
import SwiftUI
import AVKit

// MARK: - SimpleVideoPlayerViewModel

@MainActor
class SimpleVideoPlayerViewModel: ObservableObject {
    // MARK: - Published Properties (View State)
    @Published var player: AVPlayer?
    @Published var isLoading = true
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let assetService: AssetService
    private let authenticationService: AuthenticationService
    
    // MARK: - Configuration
    let asset: ImmichAsset
    
    // MARK: - Internal State
    private var hasAttemptedLoad = false
    private var hasTriedFallbackEndpoint = false
    
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
        errorMessage = nil
        
        debugLog("SimpleVideoPlayerViewModel: Loading video for asset \(asset.id)")
        
        // Validate asset type
        guard asset.type == .video else {
            debugLog("SimpleVideoPlayerViewModel: Asset is not a video")
            errorMessage = String(localized: "This asset is not a video")
            isLoading = false
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
                videoURL = try await assetService.loadOriginalVideoURL(asset: asset)
            } else {
                debugLog("SimpleVideoPlayerViewModel: Trying playback video endpoint")
                videoURL = try await assetService.loadVideoURL(asset: asset)
            }
            
            let headers = authenticationService.getAuthHeaders()
            
            debugLog("SimpleVideoPlayerViewModel: Video URL: \(videoURL)")
            debugLog("SimpleVideoPlayerViewModel: Auth headers count: \(headers.count)")
            
            // Build authenticated URL with query parameters
            let authenticatedURL = addAuthToURL(videoURL, headers: headers)
            debugLog("SimpleVideoPlayerViewModel: Authenticated URL created")
            
            // Create AVURLAsset with options
            var options: [String: Any] = [:]
            if !headers.isEmpty {
                options["AVURLAssetHTTPHeaderFieldsKey"] = headers
            }
            
            let urlAsset = AVURLAsset(url: authenticatedURL, options: options)
            
            // Verify the asset is playable before creating player
            do {
                let isPlayable = try await urlAsset.load(.isPlayable)
                
                guard isPlayable else {
                    debugLog("SimpleVideoPlayerViewModel: Asset is not playable")
                    throw VideoPlaybackError.unknown
                }
                
                debugLog("SimpleVideoPlayerViewModel: Asset verified as playable")
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
            
            // Create player
            let playerItem = AVPlayerItem(asset: urlAsset)
            let player = AVPlayer(playerItem: playerItem)
            
            debugLog("SimpleVideoPlayerViewModel: Player created successfully")
            self.player = player
            self.isLoading = false
            
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
        errorMessage = nil
        hasTriedFallbackEndpoint = true
        
        // Skip playback endpoint and go directly to original
        await loadVideoFromEndpoint(useOriginal: true)
    }
    
    /// Cleans up the player
    func cleanup() {
        debugLog("SimpleVideoPlayerViewModel: Cleaning up player")
        
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        hasAttemptedLoad = false
        hasTriedFallbackEndpoint = false
    }
    
    // MARK: - Error Handling
    
    private func handleLoadError(_ error: Error) {
        isLoading = false
        
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
