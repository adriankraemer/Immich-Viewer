//
//  SimpleVideoPlayerView.swift
//  Immich-AppleTV
//
//  Created by Codex on 2024-09-19.
//

import SwiftUI
import AVKit

/// Optimized video player with buffering support for smooth playback
struct SimpleVideoPlayerView: View {
    // MARK: - ViewModel
    @StateObject private var viewModel: SimpleVideoPlayerViewModel
    
    // MARK: - Initialization
    
    init(
        asset: ImmichAsset,
        assetService: AssetService,
        authenticationService: AuthenticationService
    ) {
        _viewModel = StateObject(wrappedValue: SimpleVideoPlayerViewModel(
            asset: asset,
            assetService: assetService,
            authenticationService: authenticationService
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let player = viewModel.player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onAppear {
                        // Player will auto-play when buffer is ready
                    }
            }
            
            // Loading overlay
            if viewModel.isLoading {
                loadingView
            }
            
            // Buffering overlay (shown during playback when rebuffering)
            if viewModel.isBuffering && !viewModel.isLoading {
                bufferingOverlay
            }
            
            // Error view
            if let message = viewModel.errorMessage {
                errorView(message: message)
            }
        }
        .task {
            await viewModel.loadVideoIfNeeded()
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text("Loading…")
                .foregroundColor(.white.opacity(0.8))
                .font(.headline)
        }
        .padding(30)
        .background(.ultraThinMaterial.opacity(0.8))
        .cornerRadius(16)
    }
    
    private var bufferingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            
            Text("Buffering…")
                .foregroundColor(.white.opacity(0.9))
                .font(.callout)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial.opacity(0.8))
        .cornerRadius(12)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            Text("Unable to play video")
                .font(.title2)
                .foregroundColor(.white)
            Text(message)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Try Again") {
                Task {
                    await viewModel.retry()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
