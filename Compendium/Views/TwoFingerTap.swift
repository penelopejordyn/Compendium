import SwiftUI
import UIKit

// MARK: - UIKit Gesture Recognizer
class TwoFingerTapGestureRecognizer: UIGestureRecognizer {
    private var touchCount = 0
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchCount = event?.allTouches?.count ?? 0

        
        if touchCount == 2 {

            state = .began
        } else if touchCount > 2 {

            state = .failed
        } else {

        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {

        if state == .began {
            state = .changed
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {

        
        if state == .began || state == .changed {

            state = .recognized
        } else {

            state = .failed
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {

        state = .failed
    }
    
    override func reset() {

        touchCount = 0
        state = .possible
    }
}

// MARK: - SwiftUI Gesture Wrapper
struct TwoFingerTapGesture: UIViewRepresentable {
    let action: () -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = true
        
        let gesture = TwoFingerTapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        view.addGestureRecognizer(gesture)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }
    
    class Coordinator: NSObject {
        let action: () -> Void
        
        init(action: @escaping () -> Void) {
            self.action = action
        }
        
        @objc func handleTap() {
            action()
        }
    }
}
extension View {
    func onTwoFingerTap(perform action: @escaping () -> Void) -> some View {
        background(  // Change from overlay to background
            TwoFingerTapGesture(action: action)
        )
    }
}
