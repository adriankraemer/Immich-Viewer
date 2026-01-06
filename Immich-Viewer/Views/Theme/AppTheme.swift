//
//  AppTheme.swift
//  Immich-Viewer
//
//  Cinematic Dark Theme - Premium Theater Experience
//

import SwiftUI

// MARK: - Theme Colors

enum AppTheme {
    // MARK: - Primary Colors
    
    /// Warm amber accent color for highlights and focus states
    static let accent = Color(red: 245/255, green: 166/255, blue: 35/255)
    
    /// Lighter amber for subtle highlights
    static let accentLight = Color(red: 255/255, green: 200/255, blue: 100/255)
    
    /// Darker amber for pressed states
    static let accentDark = Color(red: 200/255, green: 130/255, blue: 20/255)
    
    // MARK: - Background Colors
    
    /// Deep black for main backgrounds
    static let backgroundPrimary = Color(red: 13/255, green: 13/255, blue: 13/255)
    
    /// Slightly lighter for layered surfaces
    static let backgroundSecondary = Color(red: 26/255, green: 26/255, blue: 26/255)
    
    /// Card and elevated surface color
    static let surface = Color(red: 30/255, green: 30/255, blue: 32/255)
    
    /// Subtle surface for hover/unfocused cards
    static let surfaceSubtle = Color(red: 22/255, green: 22/255, blue: 24/255)
    
    // MARK: - Text Colors
    
    /// Primary text - pure white
    static let textPrimary = Color.white
    
    /// Secondary text - muted gray
    static let textSecondary = Color(red: 142/255, green: 142/255, blue: 147/255)
    
    /// Tertiary text - very subtle
    static let textTertiary = Color(red: 99/255, green: 99/255, blue: 102/255)
    
    // MARK: - Semantic Colors
    
    /// Success/positive actions
    static let success = Color(red: 52/255, green: 199/255, blue: 89/255)
    
    /// Warning states
    static let warning = Color(red: 255/255, green: 159/255, blue: 10/255)
    
    /// Error/destructive actions
    static let error = Color(red: 255/255, green: 69/255, blue: 58/255)
    
    /// Info/neutral highlights
    static let info = Color(red: 90/255, green: 200/255, blue: 250/255)
    
    // MARK: - Gradient Definitions
    
    /// Main background gradient - deep cinematic black
    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 18/255, green: 18/255, blue: 20/255),
            Color(red: 10/255, green: 10/255, blue: 12/255),
            Color(red: 5/255, green: 5/255, blue: 7/255)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// Subtle radial highlight for depth
    static let spotlightGradient = RadialGradient(
        colors: [
            Color(red: 40/255, green: 40/255, blue: 45/255).opacity(0.3),
            Color.clear
        ],
        center: .top,
        startRadius: 0,
        endRadius: 800
    )
    
    /// Card glassmorphism gradient
    static let glassGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.08),
            Color.white.opacity(0.02)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Golden glow gradient for focus states
    static let focusGlowGradient = RadialGradient(
        colors: [
            accent.opacity(0.4),
            accent.opacity(0.1),
            Color.clear
        ],
        center: .center,
        startRadius: 0,
        endRadius: 200
    )
    
    // MARK: - Shadows
    
    /// Standard card shadow
    static let cardShadow = Color.black.opacity(0.5)
    
    /// Elevated shadow for focused elements
    static let elevatedShadow = Color.black.opacity(0.7)
    
    /// Golden glow shadow for accent elements
    static let accentGlow = accent.opacity(0.3)
    
    // MARK: - Dimensions
    
    /// Standard corner radius for cards
    static let cornerRadius: CGFloat = 16
    
    /// Large corner radius for prominent elements
    static let cornerRadiusLarge: CGFloat = 24
    
    /// Small corner radius for badges/chips
    static let cornerRadiusSmall: CGFloat = 8
    
    // MARK: - Animation Durations
    
    static let animationFast: Double = 0.15
    static let animationNormal: Double = 0.25
    static let animationSlow: Double = 0.4
}

// MARK: - Glassmorphism Card Style

struct GlassmorphismCard: ViewModifier {
    let isFocused: Bool
    var cornerRadius: CGFloat = AppTheme.cornerRadius
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base glass layer
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(AppTheme.surface.opacity(isFocused ? 0.9 : 0.6))
                    
                    // Glass gradient overlay
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(AppTheme.glassGradient)
                    
                    // Border
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    isFocused ? AppTheme.accent.opacity(0.8) : Color.white.opacity(0.15),
                                    isFocused ? AppTheme.accent.opacity(0.4) : Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isFocused ? 2 : 1
                        )
                }
            )
            .shadow(
                color: isFocused ? AppTheme.accentGlow : AppTheme.cardShadow,
                radius: isFocused ? 20 : 10,
                x: 0,
                y: isFocused ? 8 : 4
            )
    }
}

// MARK: - Cinematic Button Style

struct CinematicButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : (isFocused ? 1.08 : 1.0))
            .modifier(GlassmorphismCard(isFocused: isFocused))
            .animation(.easeOut(duration: AppTheme.animationFast), value: isFocused)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Cinematic Card Button Style (for grid items)

struct CinematicCardButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : (isFocused ? 1.06 : 1.0))
            .shadow(
                color: isFocused ? AppTheme.accentGlow : Color.clear,
                radius: isFocused ? 30 : 0,
                x: 0,
                y: isFocused ? 15 : 0
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isFocused)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply glassmorphism card style
    func glassmorphismCard(isFocused: Bool = false, cornerRadius: CGFloat = AppTheme.cornerRadius) -> some View {
        modifier(GlassmorphismCard(isFocused: isFocused, cornerRadius: cornerRadius))
    }
    
    /// Apply cinematic text glow effect
    func cinematicGlow(color: Color = AppTheme.accent, radius: CGFloat = 10) -> some View {
        self.shadow(color: color.opacity(0.5), radius: radius, x: 0, y: 0)
    }
}

// MARK: - Skeleton Loading View

struct SkeletonView: View {
    @State private var isAnimating = false
    var cornerRadius: CGFloat = AppTheme.cornerRadius
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        AppTheme.surface.opacity(0.3),
                        AppTheme.surface.opacity(0.5),
                        AppTheme.surface.opacity(0.3)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: isAnimating ? 400 : -400)
            )
            .clipped()
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Cinematic Progress View

struct CinematicProgressView: View {
    var message: String = "Loading..."
    @State private var rotation: Double = 0
    
    var body: some View {
        VStack(spacing: 20) {
            // Custom animated ring
            ZStack {
                Circle()
                    .stroke(AppTheme.surface, lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        AngularGradient(
                            colors: [AppTheme.accent, AppTheme.accentLight, AppTheme.accent],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(rotation))
            }
            
            Text(message)
                .font(.headline)
                .foregroundColor(AppTheme.textSecondary)
        }
        .onAppear {
            withAnimation(
                .linear(duration: 1)
                .repeatForever(autoreverses: false)
            ) {
                rotation = 360
            }
        }
    }
}

// MARK: - Preview

#Preview("Theme Colors") {
    ScrollView {
        VStack(spacing: 20) {
            // Color swatches
            HStack(spacing: 10) {
                colorSwatch(AppTheme.accent, "Accent")
                colorSwatch(AppTheme.success, "Success")
                colorSwatch(AppTheme.warning, "Warning")
                colorSwatch(AppTheme.error, "Error")
            }
            
            // Card examples
            HStack(spacing: 20) {
                VStack {
                    Text("Unfocused")
                        .foregroundColor(AppTheme.textPrimary)
                }
                .frame(width: 200, height: 100)
                .glassmorphismCard(isFocused: false)
                
                VStack {
                    Text("Focused")
                        .foregroundColor(AppTheme.textPrimary)
                }
                .frame(width: 200, height: 100)
                .glassmorphismCard(isFocused: true)
            }
            
            // Progress view
            CinematicProgressView(message: "Loading photos...")
            
            // Skeleton
            SkeletonView()
                .frame(width: 300, height: 200)
        }
        .padding(40)
    }
    .background(AppTheme.backgroundGradient)
}

@ViewBuilder
private func colorSwatch(_ color: Color, _ name: String) -> some View {
    VStack(spacing: 8) {
        RoundedRectangle(cornerRadius: 8)
            .fill(color)
            .frame(width: 60, height: 60)
        Text(name)
            .font(.caption)
            .foregroundColor(AppTheme.textSecondary)
    }
}

