import SwiftUI
import UIKit

// MARK: - Cinematic Theme Constants
private enum SlideshowTheme {
    static let accent = Color(red: 245/255, green: 166/255, blue: 35/255)
    static let surface = Color(red: 30/255, green: 30/255, blue: 32/255)
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 142/255, green: 142/255, blue: 147/255)
    static let textTertiary = Color(red: 99/255, green: 99/255, blue: 102/255)
    static let progressActive = Color.white
    static let progressInactive = Color(red: 99/255, green: 99/255, blue: 102/255)
}

struct MemorySlideshowView: View {
    let memory: Memory
    @ObservedObject var assetService: AssetService
    @ObservedObject var authService: AuthenticationService
    
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    
    // MARK: - State
    @State private var currentIndex: Int = 0
    @State private var currentImage: UIImage?
    @State private var isLoading = true
    @State private var isPaused = false
    @State private var progress: CGFloat = 0
    @State private var autoAdvanceTimer: Timer?
    @State private var showPauseNotification = false
    
    // Memory slideshow uses a longer interval for a more relaxed viewing experience
    private let memorySlideInterval: Double = 10.0
    
    private var assets: [ImmichAsset] {
        memory.assets
    }
    
    private var currentAsset: ImmichAsset? {
        guard currentIndex < assets.count else { return nil }
        return assets[currentIndex]
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // Main content
            if isLoading {
                loadingView
            } else if let image = currentImage {
                imageContentView(image: image)
            } else {
                errorView
            }
            
            // Top bar with progress and controls
            VStack {
                topBarView
                Spacer()
            }
            
            // Navigation arrows
            navigationArrows
            
            // Pause notification overlay
            if showPauseNotification {
                pauseNotificationView
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .focusable(true)
        .focused($isFocused)
        .onAppear {
            isFocused = true
            UIApplication.shared.isIdleTimerDisabled = true
            loadCurrentImage()
            startAutoAdvance()
        }
        .onDisappear {
            stopAutoAdvance()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onExitCommand {
            dismiss()
        }
        .onPlayPauseCommand {
            togglePause()
        }
        .onMoveCommand { direction in
            switch direction {
            case .left:
                navigatePrevious()
            case .right:
                navigateNext()
            default:
                break
            }
        }
        .onTapGesture {
            dismiss()
        }
    }
    
    // MARK: - Top Bar View
    
    private var topBarView: some View {
        HStack(spacing: 16) {
            // Pause/Play button
            Button(action: { togglePause() }) {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(SlideshowTheme.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            
            // Segmented progress bar
            segmentedProgressBar
            
            // Position indicator
            Text("\(currentIndex + 1)/\(assets.count)")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(SlideshowTheme.textSecondary)
                .frame(minWidth: 50)
        }
        .padding(.horizontal, 40)
        .padding(.top, 30)
    }
    
    // MARK: - Segmented Progress Bar
    
    private var segmentedProgressBar: some View {
        GeometryReader { geometry in
            HStack(spacing: 4) {
                ForEach(0..<assets.count, id: \.self) { index in
                    segmentView(for: index, totalWidth: geometry.size.width)
                }
            }
        }
        .frame(height: 4)
    }
    
    private func segmentView(for index: Int, totalWidth: CGFloat) -> some View {
        let segmentCount = CGFloat(assets.count)
        let segmentWidth = (totalWidth - (segmentCount - 1) * 4) / segmentCount
        
        return ZStack(alignment: .leading) {
            // Background (inactive)
            RoundedRectangle(cornerRadius: 2)
                .fill(SlideshowTheme.progressInactive.opacity(0.5))
            
            // Foreground (active/progress)
            if index < currentIndex {
                // Completed segments - fully filled
                RoundedRectangle(cornerRadius: 2)
                    .fill(SlideshowTheme.progressActive)
            } else if index == currentIndex {
                // Current segment - animated progress
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(SlideshowTheme.progressActive)
                        .frame(width: geo.size.width * progress)
                }
            }
            // Future segments stay inactive (no fill)
        }
        .frame(width: segmentWidth, height: 4)
    }
    
    // MARK: - Image Content View
    
    private func imageContentView(image: UIImage) -> some View {
        GeometryReader { geometry in
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Date overlay (top-left)
                VStack {
                    HStack {
                        dateOverlay
                        Spacer()
                        actionButtons
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 80) // Below progress bar
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Date Overlay
    
    private var dateOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let asset = currentAsset {
                Text(formatDate(asset.exifInfo?.dateTimeOriginal ?? asset.fileCreatedAt))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(SlideshowTheme.textPrimary)
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Favorite button
            Button(action: { /* Toggle favorite */ }) {
                Image(systemName: currentAsset?.isFavorite == true ? "heart.fill" : "heart")
                    .font(.system(size: 24))
                    .foregroundColor(currentAsset?.isFavorite == true ? .red : SlideshowTheme.textPrimary)
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            
            // Menu button
            Button(action: { /* Show menu */ }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 24))
                    .foregroundColor(SlideshowTheme.textPrimary)
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Navigation Arrows
    
    private var navigationArrows: some View {
        HStack {
            // Left arrow
            if currentIndex > 0 {
                Button(action: { navigatePrevious() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(SlideshowTheme.textPrimary.opacity(0.7))
                        .frame(width: 80, height: 200)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Spacer().frame(width: 80)
            }
            
            Spacer()
            
            // Right arrow
            if currentIndex < assets.count - 1 {
                Button(action: { navigateNext() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(SlideshowTheme.textPrimary.opacity(0.7))
                        .frame(width: 80, height: 200)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Spacer().frame(width: 80)
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        ProgressView()
            .scaleEffect(1.5)
            .tint(SlideshowTheme.textPrimary)
    }
    
    // MARK: - Error View
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo")
                .font(.system(size: 60))
                .foregroundColor(SlideshowTheme.textTertiary)
            
            Text(String(localized: "Failed to load image"))
                .font(.headline)
                .foregroundColor(SlideshowTheme.textSecondary)
        }
    }
    
    // MARK: - Pause Notification View
    
    private var pauseNotificationView: some View {
        VStack(spacing: 16) {
            Image(systemName: isPaused ? "pause.fill" : "play.fill")
                .font(.system(size: 80, weight: .medium))
                .foregroundColor(.white)
            
            Text(isPaused ? String(localized: "Paused") : String(localized: "Playing"))
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        )
    }
    
    // MARK: - Helper Methods
    
    private func loadCurrentImage() {
        guard let asset = currentAsset else {
            isLoading = false
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let image = try await assetService.loadFullImage(asset: asset)
                await MainActor.run {
                    self.currentImage = image
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
                debugLog("MemorySlideshowView: Failed to load image: \(error)")
            }
        }
    }
    
    private func navigateNext() {
        guard currentIndex < assets.count - 1 else { return }
        currentIndex += 1
        progress = 0
        loadCurrentImage()
        restartAutoAdvance()
    }
    
    private func navigatePrevious() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        progress = 0
        loadCurrentImage()
        restartAutoAdvance()
    }
    
    private func togglePause() {
        isPaused.toggle()
        
        if isPaused {
            stopAutoAdvance()
        } else {
            startAutoAdvance()
        }
        
        showPauseNotificationBriefly()
    }
    
    private func showPauseNotificationBriefly() {
        withAnimation(.easeOut(duration: 0.2)) {
            showPauseNotification = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeIn(duration: 0.3)) {
                showPauseNotification = false
            }
        }
    }
    
    private func startAutoAdvance() {
        guard !isPaused else { return }
        
        progress = 0
        
        // Animate progress bar
        withAnimation(.linear(duration: memorySlideInterval)) {
            progress = 1.0
        }
        
        // Set timer to advance to next image
        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: memorySlideInterval, repeats: false) { _ in
            Task { @MainActor in
                if currentIndex < assets.count - 1 {
                    navigateNext()
                } else {
                    // End of memory - dismiss or loop
                    dismiss()
                }
            }
        }
    }
    
    private func stopAutoAdvance() {
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = nil
    }
    
    private func restartAutoAdvance() {
        stopAutoAdvance()
        if !isPaused {
            startAutoAdvance()
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        // Try parsing ISO8601 format
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = isoFormatter.date(from: dateString) {
            return formatDisplayDate(date)
        }
        
        // Try without fractional seconds
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) {
            return formatDisplayDate(date)
        }
        
        // Try EXIF format (YYYY:MM:DD HH:mm:ss)
        let exifFormatter = DateFormatter()
        exifFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        if let date = exifFormatter.date(from: dateString) {
            return formatDisplayDate(date)
        }
        
        return dateString
    }
    
    private func formatDisplayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    let mockAsset = ImmichAsset(
        id: "mock-1",
        deviceAssetId: "device-1",
        deviceId: "device-1",
        ownerId: "owner-1",
        libraryId: nil,
        type: .image,
        originalPath: "/mock/path",
        originalFileName: "photo.jpg",
        originalMimeType: "image/jpeg",
        resized: false,
        thumbhash: nil,
        fileModifiedAt: "2024-01-09T00:00:00Z",
        fileCreatedAt: "2024-01-09T00:00:00Z",
        localDateTime: "2024-01-09T00:00:00Z",
        updatedAt: "2024-01-09T00:00:00Z",
        isFavorite: false,
        isArchived: false,
        isOffline: false,
        isTrashed: false,
        checksum: "mock-checksum",
        duration: nil,
        hasMetadata: true,
        livePhotoVideoId: nil,
        people: [],
        visibility: "VISIBLE",
        duplicateId: nil,
        exifInfo: nil
    )
    
    let mockMemory = Memory(
        id: "memory-2-years",
        yearsAgo: 2,
        date: Calendar.current.date(byAdding: .year, value: -2, to: Date())!,
        assets: [mockAsset]
    )
    
    let userManager = UserManager()
    let networkService = NetworkService(userManager: userManager)
    let assetService = AssetService(networkService: networkService)
    let authService = AuthenticationService(networkService: networkService, userManager: userManager)
    
    return MemorySlideshowView(
        memory: mockMemory,
        assetService: assetService,
        authService: authService
    )
}
