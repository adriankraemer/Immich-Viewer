import Foundation
import SwiftUI

// MARK: - Slideshow Settings Component

struct SlideshowSettings: View {
    @Binding var slideshowInterval: Double
    @Binding var slideshowBackgroundColor: String
    @Binding var use24HourClock: Bool
    @Binding var hideOverlay: Bool
    @Binding var enableReflections: Bool
    @Binding var enableKenBurns: Bool
    @Binding var enableShuffle: Bool
    @Binding var autoSlideshowTimeout: Int
    @FocusState.Binding var isMinusFocused: Bool
    @FocusState.Binding var isPlusFocused: Bool
    @FocusState.Binding var focusedColor: String?
    
    
    var body: some View {
        VStack(spacing: 12) {
            // Slideshow Interval Setting
            SettingsRow(
                icon: "timer",
                title: "Slideshow Interval",
                subtitle: "Time between slides in slideshow mode",
                content: AnyView(
                    HStack(spacing: 40) {
                        Button(action: {
                            debugLog("clicked -")
                            debugLog("\(slideshowInterval)")
                            if slideshowInterval > 30 {
                                // Above 30s: decrement by 30s
                                slideshowInterval -= 30
                            } else if slideshowInterval == 30 {
                                // Jump from 30s back to 15s
                                slideshowInterval = 15
                            } else if slideshowInterval > 3 {
                                // 3-15s: decrement by 1s
                                slideshowInterval -= 1
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(isMinusFocused ? .white : .blue)
                                .font(.title2)
                        }
                        .buttonStyle(CustomFocusButtonStyle())
                        .focused($isMinusFocused)
                        
                        Text("\(Int(slideshowInterval))s")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .frame(minWidth: 50)
                            .id("slideshow-interval-\(Int(slideshowInterval))")
                        
                        Button(action: {
                            debugLog("clicked +")
                            debugLog("\(slideshowInterval)")
                            if slideshowInterval == 15 {
                                // Jump from 15s to 30s
                                slideshowInterval = 30
                            } else if slideshowInterval >= 30 && slideshowInterval < 120 {
                                // 30s and above: increment by 30s (max 120s)
                                slideshowInterval += 30
                            } else if slideshowInterval < 15 {
                                // Below 15s: increment by 1s
                                slideshowInterval += 1
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(isPlusFocused ? .white : .blue)
                                .font(.title2)
                        }
                        .buttonStyle(CustomFocusButtonStyle())
                        .focused($isPlusFocused)
                    }
                )
            )
            
            // Slideshow Background Color Setting
            SettingsRow(
                icon: "paintbrush",
                title: "Slideshow Background",
                subtitle: "Background style for slideshow mode",
                content: AnyView(
                    HStack {
                        // Color preview circle
                        Group {
                            if slideshowBackgroundColor == "ambilight" {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(
                                            colors: [.purple, .blue, .cyan, .yellow, .orange],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                    Image(systemName: "rays")
                                        .foregroundColor(.white)
                                        .font(.caption)
                                }
                            } else {
                                Circle()
                                    .fill(getBackgroundColor(slideshowBackgroundColor))
                            }
                        }
                        .frame(width: 32, height: 32)
                        
                        Picker("Background", selection: $slideshowBackgroundColor) {
                            Text("Ambilight").tag("ambilight")
                            Text("Black").tag("black")
                            Text("White").tag("white")
                            Text("Gray").tag("gray")
                            Text("Blue").tag("blue")
                            Text("Purple").tag("purple")
                        }
                        .pickerStyle(.menu)
                    }
                )
            )
            
            // Clock Format Setting
             SettingsRow(
                 icon: "clock",
                 title: "Clock Format",
                 subtitle: "Time format for slideshow overlay.",
                 content: AnyView(
                     Picker("Clock Format", selection: $use24HourClock) {
                         Text("12 Hour").tag(false)
                         Text("24 Hour").tag(true)
                     }
                         .pickerStyle(.menu)
                         .frame(width: 300, alignment: .trailing)
                 )
             )
            
            SettingsRow(
                icon: "camera.macro.circle",
                title: "Image Effects",
                subtitle: "Choose visual effects for slideshow images",
                content: AnyView(
                    Picker("Image Effects", selection: Binding(
                        get: {
                            if enableKenBurns {
                                return "kenBurns"
                            } else if enableReflections {
                                return "reflections"
                            } else {
                                return "none"
                            }
                        },
                        set: { newValue in
                            switch newValue {
                            case "kenBurns":
                                enableKenBurns = true
                                enableReflections = false
                            case "reflections":
                                enableKenBurns = false
                                enableReflections = true
                            default: // "none"
                                enableKenBurns = false
                                enableReflections = false
                            }
                        }
                    )) {
                        Text("None").tag("none")
                        Text("Reflections").tag("reflections")
                        Text("Pan and Zoom").tag("kenBurns")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 400, alignment: .trailing)
                )
            )
            
            SettingsRow(
                icon: "shuffle",
                title: "Shuffle Images (beta)",
                subtitle: "Randomly shuffle image order during slideshow",
                content: AnyView(
                    Picker("Shuffle Images", selection: $enableShuffle) {
                        Text("Off").tag(false)
                        Text("On").tag(true)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 300, alignment: .trailing)
                ),
                isOn: enableShuffle
            )
            
            SettingsRow(
                icon: "eye.slash",
                title: "Hide Image Overlays",
                subtitle: "Hide clock, date, location overlay from slideshow and fullscreen view.",
                content: AnyView(
                    Picker("Hide Image Overlays", selection: $hideOverlay) {
                        Text("Off").tag(false)
                        Text("On").tag(true)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 300, alignment: .trailing)
                ),
                isOn: hideOverlay
                
            )
            
             SettingsRow(
                 icon: "clock.arrow.circlepath",
                 title: "Auto-Start Slideshow",
                 subtitle: "Start slideshow after inactivity",
                 content: AnyView(AutoSlideshowTimeoutPicker(timeout: $autoSlideshowTimeout)),
                 isOn: autoSlideshowTimeout > 0
             )
            
             
        }
    }
    
    private func getBackgroundColor(_ colorName: String) -> Color {
        switch colorName {
        case "ambilight": return .black // Fallback for preview, actual ambilight is handled in slideshow
        case "black": return .black
        case "white": return .white
        case "gray": return .gray
        case "blue": return .blue
        case "purple": return .purple
        default: return .black
        }
    }
}


#Preview {
    @Previewable @State var slideshowInterval: Double = 8.0
    @Previewable @State var slideshowBackgroundColor = "ambilight"
    @Previewable @State var use24HourClock = true
    @Previewable @State var hideOverlay = true
    @Previewable @State var enableReflections = true
    @Previewable @State var enableKenBurns = false
    @Previewable @State var enableShuffle = false
    @Previewable @State var autoSlideshowTimeout = 5
    @Previewable @FocusState var isMinusFocused: Bool
    @Previewable @FocusState var isPlusFocused: Bool
    @Previewable @FocusState var focusedColor: String?
    
    return SlideshowSettings(
        slideshowInterval: $slideshowInterval,
        slideshowBackgroundColor: $slideshowBackgroundColor,
        use24HourClock: $use24HourClock,
        hideOverlay: $hideOverlay,
        enableReflections: $enableReflections,
        enableKenBurns: $enableKenBurns,
        enableShuffle: $enableShuffle,
        autoSlideshowTimeout: $autoSlideshowTimeout,
        isMinusFocused: $isMinusFocused,
        isPlusFocused: $isPlusFocused,
        focusedColor: $focusedColor
    )
    .preferredColorScheme(.light)
    .padding()
}

