import SwiftUI

struct CacheSettingsView: View {
    @ObservedObject var thumbnailCache: ThumbnailCache
    @State private var showingClearCacheAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                CacheSection(
                    thumbnailCache: thumbnailCache,
                    showingClearCacheAlert: $showingClearCacheAlert
                )
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
        }
        .alert("Clear Cache", isPresented: $showingClearCacheAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                thumbnailCache.clearAllCaches()
            }
        } message: {
            Text("This will remove all cached thumbnails from both memory and disk. Images will be re-downloaded when needed.")
        }
        .onAppear {
            thumbnailCache.refreshCacheStatistics()
        }
    }
}

