//
//  AboutSettingsView.swift
//  Immich-Viewer
//
//  Created by Adrian Kraemer on 2025-01-06.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

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
    
    // Pre-generated QR code images to avoid blocking the main thread
    @State private var websiteQRCode: UIImage?
    @State private var immichQRCode: UIImage?
    @State private var appStoreQRCode: UIImage?
    
    var body: some View {
        VStack(spacing: 40) {
            // Hero Section with App Logo
            heroSection
            
            // Credits Content
            creditsSection
        }
        .task {
            // Generate QR codes asynchronously on a background thread
            async let website = generateQRCodeAsync(from: "https://immich.adriank.app")
            async let immich = generateQRCodeAsync(from: "https://immich.app")
            async let appStore = generateQRCodeAsync(from: "https://apps.apple.com/us/app/immich-viewer/id6757225201")
            
            let (websiteResult, immichResult, appStoreResult) = await (website, immich, appStore)
            
            websiteQRCode = websiteResult
            immichQRCode = immichResult
            appStoreQRCode = appStoreResult
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
                
                Text(String(localized: "for Apple TV"))
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(AboutTheme.accent)
                    .tracking(2)
                    .textCase(.uppercase)
                
                // Version badge
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    Text(String(localized: "Version \(version) (\(build))"))
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
            
            // Developer Credit
            developerCredit
            
            // Links Section with QR Codes - Grid Layout
            HStack(spacing: 20) {
                Spacer()
                
                qrCodeCard(
                    title: String(localized: "App Website"),
                    icon: "globe",
                    url: "https://immich.adriank.app",
                    gradient: [AboutTheme.accent, AboutTheme.accentLight],
                    qrImage: websiteQRCode
                )
                
                qrCodeCard(
                    title: String(localized: "Immich"),
                    icon: "photo.stack",
                    url: "https://immich.app",
                    gradient: [AboutTheme.immichPink, AboutTheme.immichBlue],
                    qrImage: immichQRCode
                )
                
                qrCodeCard(
                    title: String(localized: "App Store"),
                    icon: "star.fill",
                    url: "https://apps.apple.com/us/app/immich-viewer/id6757225201",
                    gradient: [AboutTheme.immichBlue, AboutTheme.immichGreen],
                    qrImage: appStoreQRCode
                )
                
                Spacer()
            }
            
            // Open Source Acknowledgment
            openSourceCard
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 60)
        .opacity(contentOpacity)
    }
    
    // MARK: - Developer Credit
    
    private var developerCredit: some View {
        VStack(spacing: 12) {
            Text(String(localized: "Developer"))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(AboutTheme.textSecondary)
                .tracking(1.5)
                .textCase(.uppercase)
            
            Text("Adrian Krämer")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AboutTheme.textPrimary, AboutTheme.accent.opacity(0.9)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .padding(.vertical, 20)
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
    
    // MARK: - QR Code Generator (Async)
    
    private func generateQRCodeAsync(from string: String) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            let context = CIContext()
            let filter = CIFilter.qrCodeGenerator()
            
            filter.message = Data(string.utf8)
            filter.correctionLevel = "M"
            
            guard let outputImage = filter.outputImage else { return nil }
            
            // Scale up the QR code for better quality
            let scale = 10.0
            let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            
            guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
            
            return UIImage(cgImage: cgImage)
        }.value
    }
    
    // MARK: - QR Code Card
    
    private func qrCodeCard(title: String, icon: String, url: String, gradient: [Color], qrImage: UIImage?) -> some View {
        Button(action: {
            // QR codes are for scanning, no action needed
        }) {
            VStack(spacing: 16) {
                // Icon with gradient background
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: gradient.map { $0.opacity(0.2) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                // Title
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AboutTheme.textPrimary)
                
                // QR Code
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .frame(width: 140, height: 140)
                    
                    if let qrImage {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                    } else {
                        ProgressView()
                            .frame(width: 120, height: 120)
                    }
                }
                .shadow(color: gradient[0].opacity(0.3), radius: 12, x: 0, y: 4)
                
                // URL display
                Text(URL(string: url)?.host ?? url)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(gradient[0].opacity(0.9))
                    .lineLimit(1)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(AboutTheme.surface.opacity(0.6))
                    
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.04), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: 20)
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
    
    // MARK: - Link Button (Deprecated)
    
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
                Text(String(localized: "Powered by Immich"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AboutTheme.textPrimary)
                
                Text(String(localized: "Immich is a high-performance, self-hosted photo and video management solution."))
                    .font(.system(size: 16))
                    .foregroundColor(AboutTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 12))
                    Text(String(localized: "Open Source"))
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

