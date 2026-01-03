import SwiftUI

// Shared background gradient for consistent styling across the app
// Cinematic Dark Theme - Premium Theater Experience
struct SharedGradientBackground: View {
    var body: some View {
        ZStack {
            // Base deep black gradient
            LinearGradient(
                colors: [
                    Color(red: 18/255, green: 18/255, blue: 20/255),
                    Color(red: 10/255, green: 10/255, blue: 12/255),
                    Color(red: 5/255, green: 5/255, blue: 7/255)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Subtle spotlight effect from top center for depth
            RadialGradient(
                colors: [
                    Color(red: 40/255, green: 40/255, blue: 45/255).opacity(0.25),
                    Color.clear
                ],
                center: .top,
                startRadius: 0,
                endRadius: 900
            )
            
            // Subtle warm ambient glow at bottom
            RadialGradient(
                colors: [
                    Color(red: 245/255, green: 166/255, blue: 35/255).opacity(0.03),
                    Color.clear
                ],
                center: .bottom,
                startRadius: 0,
                endRadius: 600
            )
            
            // Noise texture overlay for cinematic feel
            NoiseTextureView()
                .opacity(0.02)
        }
        .ignoresSafeArea()
    }
}

// Subtle noise texture for cinematic depth
struct NoiseTextureView: View {
    var body: some View {
        Canvas { context, size in
            for _ in 0..<Int(size.width * size.height / 100) {
                let x = CGFloat.random(in: 0..<size.width)
                let y = CGFloat.random(in: 0..<size.height)
                let opacity = Double.random(in: 0.1...0.3)
                
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                    with: .color(Color.white.opacity(opacity))
                )
            }
        }
    }
}

// Shared utility function for background colors
func getBackgroundColor(_ colorString: String) -> Color {
    switch colorString {
    case "ambilight":
        return .black // Fallback for non-slideshow contexts, actual ambilight handled in view
    case "black":
        return .black
    case "white":
        return .white
    case "gray":
        return .gray
    case "blue":
        return .blue
    case "purple":
        return .purple
    default:
        return .black
    }
}

// Custom button style with cinematic golden glow on focus
struct CustomFocusButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused
    
    private let accentColor = Color(red: 245/255, green: 166/255, blue: 35/255)
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : (isFocused ? 1.15 : 1.0))
            .background(
                Circle()
                    .fill(isFocused ? accentColor.opacity(0.2) : Color.clear)
                    .frame(width: 50, height: 50)
            )
            .shadow(
                color: isFocused ? accentColor.opacity(0.4) : Color.clear,
                radius: isFocused ? 15 : 0,
                x: 0,
                y: 0
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Custom focusable button style for color selection with cinematic styling
struct ColorSelectionButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused
    
    private let accentColor = Color(red: 245/255, green: 166/255, blue: 35/255)
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : (isFocused ? 1.1 : 1.0))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isFocused ? accentColor : Color.clear,
                        lineWidth: 3
                    )
            )
            .shadow(
                color: isFocused ? accentColor.opacity(0.5) : Color.clear,
                radius: isFocused ? 12 : 0,
                x: 0,
                y: 0
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Card button style for Apple TV - cinematic lift effect with golden glow
struct CardButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused
    
    private let accentColor = Color(red: 245/255, green: 166/255, blue: 35/255)
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : (isFocused ? 1.06 : 1.0))
            .shadow(
                color: isFocused ? accentColor.opacity(0.35) : Color.black.opacity(0.3),
                radius: isFocused ? 25 : 8,
                x: 0,
                y: isFocused ? 12 : 4
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isFocused)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SharedOpaqueBackground: View {
    var body: some View {
        ZStack {
            // Deep cinematic black
            Color(red: 8/255, green: 8/255, blue: 10/255)
            
            // Subtle vignette effect
            RadialGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.3)
                ],
                center: .center,
                startRadius: 400,
                endRadius: 1200
            )
        }
        .ignoresSafeArea()
    }
}

#Preview {
    SharedGradientBackground()
}
