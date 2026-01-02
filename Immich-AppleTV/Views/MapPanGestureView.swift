import SwiftUI
import UIKit

struct MapPanGestureView: UIViewRepresentable {
    let onPan: (PanDirection) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.clear
        view.isUserInteractionEnabled = true
        
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan))
        view.addGestureRecognizer(panGesture)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPan: onPan)
    }
    
    class Coordinator: NSObject {
        let onPan: (PanDirection) -> Void
        private var lastPanTime: Date = Date()
        private let panThrottle: TimeInterval = 0.1 // Throttle pan events to avoid too many updates
        
        init(onPan: @escaping (PanDirection) -> Void) {
            self.onPan = onPan
        }
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let now = Date()
            guard now.timeIntervalSince(lastPanTime) >= panThrottle else {
                return
            }
            lastPanTime = now
            
            let translation = gesture.translation(in: gesture.view)
            let velocity = gesture.velocity(in: gesture.view)
            
            // Determine pan direction based on translation and velocity
            if abs(translation.x) > abs(translation.y) {
                // Horizontal pan
                if translation.x > 10 || velocity.x > 100 {
                    onPan(.right)
                } else if translation.x < -10 || velocity.x < -100 {
                    onPan(.left)
                }
            } else {
                // Vertical pan
                if translation.y < -10 || velocity.y < -100 {
                    onPan(.up)
                } else if translation.y > 10 || velocity.y > 100 {
                    onPan(.down)
                }
            }
            
            // Reset translation to avoid accumulation
            gesture.setTranslation(.zero, in: gesture.view)
        }
    }
}


