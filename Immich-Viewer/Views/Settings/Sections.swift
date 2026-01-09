import Foundation
import SwiftUI

// MARK: - Cinematic Theme Constants for Sections
private enum SectionTheme {
    static let accent = Color(red: 245/255, green: 166/255, blue: 35/255)
    static let surface = Color(red: 30/255, green: 30/255, blue: 32/255)
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 142/255, green: 142/255, blue: 147/255)
}

// MARK: - Cache Section Component

struct CacheSection: View {
    @ObservedObject var thumbnailCache: ThumbnailCache
    @Binding var showingClearCacheAlert: Bool
    
    var body: some View {
        SettingsSection(title: String(localized: "Cache")) {
            AnyView(VStack(spacing: 16) {
                // Cache Actions
                HStack(spacing: 16) {
                    ActionButton(
                        icon: "clock.arrow.circlepath",
                        title: String(localized: "Clear Expired"),
                        color: .orange
                    ) {
                        thumbnailCache.clearExpiredCache()
                    }
                    
                    ActionButton(
                        icon: "trash",
                        title: String(localized: "Clear All"),
                        color: .red
                    ) {
                        showingClearCacheAlert = true
                    }
                }
                
                // Cache Information
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "Current Usage"))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(String(localized: "Memory Cache"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatBytes(thumbnailCache.memoryCacheSize))
                                .font(.caption)
                                .foregroundColor(.primary)
                            Text(String(localized: "\(thumbnailCache.memoryCacheCount) images"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text(String(localized: "Disk Cache"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatBytes(thumbnailCache.diskCacheSize))
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        Text(String(localized: "Total Cache"))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(formatBytes(thumbnailCache.memoryCacheSize + thumbnailCache.diskCacheSize))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }
                .padding(16)
                .background(Color.gray.opacity(0.03))
                .cornerRadius(12)
                
                // Cache Limits
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "Cache Limits"))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(String(localized: "Memory Limit"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatBytes(100 * 1024 * 1024))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(String(localized: "Disk Limit"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatBytes(500 * 1024 * 1024))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(String(localized: "Expiration"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(localized: "7 days"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(16)
                .background(Color.gray.opacity(0.03))
                .cornerRadius(12)
            })
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

struct SettingsSection: View {
    let title: String
    let content: () -> AnyView
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Section header with cinematic styling
            HStack(spacing: 16) {
                // Accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(SectionTheme.accent)
                    .frame(width: 4, height: 32)
                
                Text(title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(SectionTheme.textPrimary)
                
                Spacer()
            }
            .padding(.bottom, 4)
            
            VStack(spacing: 16) {
                content()
            }
        }
        .padding(.vertical, 12)
    }
}


struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(SectionTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(SectionTheme.surface.opacity(0.6))
                    
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            LinearGradient(
                                colors: [color.opacity(0.3), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
        }
        .buttonStyle(CardButtonStyle())
    }
}
