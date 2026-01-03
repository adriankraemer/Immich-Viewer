import SwiftUI

// Shared background gradient for consistent styling across the app
// Cinematic Dark Theme - Premium Theater Experience
// Optimized for scroll performance
struct SharedGradientBackground: View {
    var body: some View {
        // Simple gradient - removed expensive radial gradients and noise for performance
        LinearGradient(
            colors: [
                Color(red: 16/255, green: 16/255, blue: 18/255),
                Color(red: 8/255, green: 8/255, blue: 10/255)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
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
// Optimized: only apply shadow when focused to reduce GPU load during scrolling
struct CardButtonStyle: ButtonStyle {
    @Environment(\.isFocused) var isFocused
    
    private let accentColor = Color(red: 245/255, green: 166/255, blue: 35/255)
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : (isFocused ? 1.05 : 1.0))
            // Only apply shadow when focused for better scroll performance
            .shadow(
                color: isFocused ? accentColor.opacity(0.3) : Color.clear,
                radius: isFocused ? 15 : 0,
                x: 0,
                y: isFocused ? 8 : 0
            )
            .animation(.easeOut(duration: 0.2), value: isFocused)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SharedOpaqueBackground: View {
    var body: some View {
        // Simple solid color for performance
        Color(red: 8/255, green: 8/255, blue: 10/255)
            .ignoresSafeArea()
    }
}

#Preview {
    SharedGradientBackground()
}
