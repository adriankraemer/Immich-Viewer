//
//  AboutSettingsView.swift
//  Immich-Viewer
//
//  Created by Adrian Kraemer on 2025-01-06.
//

import SwiftUI

// MARK: - About Theme Constants
private enum AboutTheme {
    static let accent = Color(red: 245/255, green: 166/255, blue: 35/255)
    static let accentLight = Color(red: 255/255, green: 200/255, blue: 100/255)
    static let surface = Color(red: 30/255, green: 30/255, blue: 32/255)
    static let surfaceLight = Color(red: 45/255, green: 45/255, blue: 48/255)
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 142/255, green: 142/255, blue: 147/255)
    static let immichPink = Color(red: 237/255, green: 121/255, blue: 181/255)
    static let immichGreen = Color(red: 61/255, green: 220/255, blue: 151/255)
    static let immichBlue = Color(red: 76/255, green: 111/255, blue: 255/255)
    static let immichRed = Color(red: 250/255, green: 41/255, blue: 33/255)
    static let immichYellow = Color(red: 255/255, green: 180/255, blue: 0/255)
}

// MARK: - About Settings View

struct AboutSettingsView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    
    var body: some View {
        VStack(spacing: 40) {
            // Hero Section with App Logo
            heroSection
                .focusSection()
            
            // Credits Content
            creditsSection
                .focusSection()
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
                contentOpacity = 1.0
            }
        }
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        VStack(spacing: 24) {
            // App Logo with glow effect
            ZStack {
                // Glow layers
                Image("icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 180, height: 180)
                    .blur(radius: 40)
                    .opacity(0.5)
                
                Image("icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 180, height: 180)
                    .blur(radius: 20)
                    .opacity(0.3)
                
                // Main logo
                Image("icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .shadow(color: AboutTheme.accent.opacity(0.4), radius: 20, x: 0, y: 8)
            }
            .scaleEffect(logoScale)
            .opacity(logoOpacity)
            
            // App Name with cinematic typography
            VStack(spacing: 8) {
                Text("Immich Viewer")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AboutTheme.textPrimary, AboutTheme.textPrimary.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                Text("for Apple TV")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(AboutTheme.accent)
                    .tracking(2)
                    .textCase(.uppercase)
                
                // Version badge
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    Text("Version \(version) (\(build))")
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor(AboutTheme.textSecondary)
                        .padding(.top, 4)
                }
            }
            .opacity(logoOpacity)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Credits Section
    
    private var creditsSection: some View {
        VStack(spacing: 32) {
            // Divider with film reel aesthetic
            filmDivider
            
            // Links Section
            VStack(spacing: 16) {
                linkButton(
                    title: "App Website",
                    subtitle: "immich.adriank.app",
                    icon: "globe",
                    url: "https://immich.adriank.app",
                    gradient: [AboutTheme.accent, AboutTheme.accentLight]
                )
                
                linkButton(
                    title: "Immich",
                    subtitle: "Self-hosted photo & video backup",
                    icon: "photo.stack",
                    url: "https://immich.app",
                    gradient: [AboutTheme.immichPink, AboutTheme.immichBlue]
                )
                
                linkButton(
                    title: "Immich on GitHub",
                    subtitle: "Open source • MIT License",
                    icon: "chevron.left.forwardslash.chevron.right",
                    url: "https://github.com/immich-app/immich",
                    gradient: [AboutTheme.immichGreen, AboutTheme.immichBlue]
                )
            }
            
            // Open Source Acknowledgment
            openSourceCard
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 60)
        .opacity(contentOpacity)
    }
    
    // MARK: - Film Divider
    
    private var filmDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, AboutTheme.accent.opacity(0.5)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
            
            // Film reel holes
            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AboutTheme.accent.opacity(0.6))
                        .frame(width: 12, height: 8)
                }
            }
            
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [AboutTheme.accent.opacity(0.5), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Link Button
    
    private func linkButton(title: String, subtitle: String, icon: String, url: String, gradient: [Color]) -> some View {
        Button(action: {
            // On tvOS, we can't open URLs directly, but we display them for users to visit
            // The URL is shown in the subtitle for reference
        }) {
            HStack(spacing: 20) {
                // Icon with gradient background
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: gradient.map { $0.opacity(0.2) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(AboutTheme.textPrimary)
                    
                    Text(subtitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AboutTheme.textSecondary)
                }
                
                Spacer()
                
                // URL display
                Text(URL(string: url)?.host ?? url)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(gradient[0].opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(gradient[0].opacity(0.1))
                    )
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AboutTheme.textSecondary)
            }
            .padding(24)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(AboutTheme.surface.opacity(0.6))
                    
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.04), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(
                            LinearGradient(
                                colors: [gradient[0].opacity(0.25), Color.white.opacity(0.05)],
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
    
    // MARK: - Open Source Card
    
    private var openSourceCard: some View {
        VStack(spacing: 16) {
            // Immich colors stripe
            HStack(spacing: 0) {
                Rectangle().fill(AboutTheme.immichRed)
                Rectangle().fill(AboutTheme.immichPink)
                Rectangle().fill(AboutTheme.immichYellow)
                Rectangle().fill(AboutTheme.immichBlue)
                Rectangle().fill(AboutTheme.immichGreen)
            }
            .frame(height: 4)
            .clipShape(Capsule())
            .padding(.horizontal, 60)
            
            VStack(spacing: 8) {
                Text("Powered by Immich")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AboutTheme.textPrimary)
                
                Text("Immich is a high-performance, self-hosted photo and video management solution.")
                    .font(.system(size: 16))
                    .foregroundColor(AboutTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 12))
                    Text("Open Source")
                    Text("•")
                    Text("AGPL-3.0 License")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AboutTheme.immichGreen)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(AboutTheme.surface.opacity(0.4))
                
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                AboutTheme.immichPink.opacity(0.2),
                                AboutTheme.immichBlue.opacity(0.2),
                                AboutTheme.immichGreen.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .padding(.top, 16)
    }
}

#Preview {
    ZStack {
        SharedGradientBackground()
            .ignoresSafeArea()
        
        ScrollView {
            AboutSettingsView()
                .padding(40)
        }
    }
}

