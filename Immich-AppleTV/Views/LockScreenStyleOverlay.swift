import SwiftUI

// MARK: - Cinematic Theme for Overlay
private enum OverlayTheme {
    static let accent = Color(red: 245/255, green: 166/255, blue: 35/255)
    static let surface = Color(red: 20/255, green: 20/255, blue: 22/255)
}

// MARK: - LockScreenStyleOverlay View
struct LockScreenStyleOverlay: View {
    let asset: ImmichAsset
    let isSlideshowMode: Bool // Determines larger font sizes for slideshow
    
    @State private var currentTime = Date()
    @State private var timeUpdateTimer: Timer?
    @AppStorage("use24HourClock") private var use24HourClock = false
    
    init(asset: ImmichAsset, isSlideshowMode: Bool = false) {
        self.asset = asset
        self.isSlideshowMode = isSlideshowMode
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 24) {
            // MARK: - Clock and Date Display (Slideshow Mode)
            if isSlideshowMode {
                VStack(alignment: .trailing, spacing: 12) {
                    // Current time with cinematic styling
                    Text(formatCurrentTime())
                        .font(.system(size: 100, weight: .thin, design: .default))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.8), radius: 20, x: 0, y: 8)
                    
                    // Current date
                    Text(formatCurrentDate())
                        .font(.system(size: 32, weight: .light, design: .default))
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.6), radius: 10, x: 0, y: 4)
                }
                .padding(.horizontal, 48)
                .padding(.top, 16)
                .padding(.bottom, 28)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(OverlayTheme.surface.opacity(0.75))
                        
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.08), Color.clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                )
                .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
            }
            
            Spacer()
            
            // MARK: - Photo Info with Glassmorphism
            VStack(alignment: .trailing, spacing: 8) {
                // People names
                let nonEmptyNames = asset.people.map(\.name).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                
                if !nonEmptyNames.isEmpty {
                    Text(nonEmptyNames.joined(separator: ", "))
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                // Location with icon
                if let location = getLocationString() {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 18))
                            .foregroundColor(OverlayTheme.accent)
                        Text(location)
                            .font(.system(size: 20, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))
                    }
                }
                
                // Date with icon
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 18))
                        .foregroundColor(OverlayTheme.accent)
                    Text(getDisplayDate())
                        .font(.system(size: 20, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(OverlayTheme.surface.opacity(0.7))
                    
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.06), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .onAppear {
            if isSlideshowMode {
                startTimeUpdate()
            }
        }
        .onDisappear {
            stopTimeUpdate()
        }
    }
    
    // MARK: - Logic Functions (Unchanged)
    private func getDisplayDate() -> String {
        if let dateTimeOriginal = asset.exifInfo?.dateTimeOriginal {
            return formatDisplayDate(dateTimeOriginal)
        } else {
            return formatDisplayDate(asset.fileCreatedAt)
        }
    }
    
    private func formatDisplayDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        
        // Try EXIF date format first
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        
        // Try ISO date format
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC") // Important for 'Z' suffix
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
    
    private func getLocationString() -> String? {
        if let city = asset.exifInfo?.city, let state = asset.exifInfo?.state, let country = asset.exifInfo?.country {
            return "\(city), \(state), \(country)"
        } else if let city = asset.exifInfo?.city, let country = asset.exifInfo?.country {
            return "\(city), \(country)"
        } else if let country = asset.exifInfo?.country {
            return country
        }
        return nil
    }
    
    // MARK: - Time Management for Slideshow Mode (Unchanged logic)
    
    private func formatCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = use24HourClock ? "HH:mm" : "h:mm a"
        return formatter.string(from: currentTime)
    }
    
    private func formatCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full // e.g., "Friday, July 5, 2025"
        formatter.timeStyle = .none
        return formatter.string(from: currentTime)
    }
    
    private func startTimeUpdate() {
        // Invalidate any existing timer first to prevent duplicates
        stopTimeUpdate()
        // Update time immediately
        currentTime = Date()
        
        // Set up timer to update every second
        timeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }
    
    private func stopTimeUpdate() {
        timeUpdateTimer?.invalidate()
        timeUpdateTimer = nil
    }
}


#Preview {
    SlideshowView(albumId: nil, personId: nil, tagId: nil, city: nil, startingAssetId: nil, isFavorite: false)
}
