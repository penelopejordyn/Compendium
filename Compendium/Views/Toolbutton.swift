import SwiftUI

struct FloatingToolButton: View {
    @Binding var position: CGPoint
    @Binding var isToolPickerPresented: Bool
    let action: () -> Void
    
    // Screen edge snap threshold
    private let snapDistance: CGFloat = 20
    private let buttonSize: CGFloat = 44
    private let minimumDragDistance: CGFloat = 3.0
    
    @State private var isDragging = false
    @GestureState private var dragOffset = CGSize.zero
    @GestureState private var isPressingButton = false
    
    var body: some View {
        let dragGesture = DragGesture(minimumDistance: minimumDragDistance)
            .updating($dragOffset) { value, state, _ in
                if isDragging {
                    state = value.translation
                }
            }
            .onChanged { _ in
                isDragging = true
            }
            .onEnded { value in
                handleDragEnd(with: value)
                isDragging = false
            }
        
        let pressGesture = DragGesture(minimumDistance: 0)
            .updating($isPressingButton) { value, state, _ in
                state = true
            }
            .onEnded { value in
                // If drag distance is small, treat as tap
                if abs(value.translation.width) < minimumDragDistance &&
                    abs(value.translation.height) < minimumDragDistance {
                    action()
                }
            }
        
        Image(systemName: "paintbrush.pointed")
            .font(.title2)
            .foregroundColor(.white)
            .frame(width: buttonSize, height: buttonSize)
            .background(isToolPickerPresented ? Color.white.opacity(0.3) : Color(red: 1, green: 0.2157, blue: 0.3725))
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.2), radius: 5)
            .scaleEffect(isPressingButton ? 0.95 : (isDragging ? 1.1 : 1.0))
            .position(position)
            .offset(x: dragOffset.width, y: dragOffset.height)
            .gesture(dragGesture)
            .simultaneousGesture(pressGesture)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressingButton)
            .animation(.easeInOut(duration: 0.2), value: isToolPickerPresented)
    }
    
    private func handleDragEnd(with value: DragGesture.Value) {
        let newPosition = CGPoint(
            x: position.x + value.translation.width,
            y: position.y + value.translation.height
        )
        
        let screen = UIScreen.main.bounds
        
        // Calculate distances to edges
        let leftDistance = newPosition.x
        let rightDistance = screen.width - newPosition.x
        let topDistance = newPosition.y
        let bottomDistance = screen.height - newPosition.y
        
        // Snap to nearest edge if within threshold
        var snappedX = newPosition.x
        var snappedY = newPosition.y
        
        if leftDistance < snapDistance {
            snappedX = buttonSize/2
        } else if rightDistance < snapDistance {
            snappedX = screen.width - buttonSize/2
        }
        
        if topDistance < snapDistance {
            snappedY = buttonSize/2
        } else if bottomDistance < snapDistance {
            snappedY = screen.height - buttonSize/2
        }
        
        // Ensure button stays within screen bounds
        snappedX = max(buttonSize/2, min(screen.width - buttonSize/2, snappedX))
        snappedY = max(buttonSize/2, min(screen.height - buttonSize/2, snappedY))
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            position = CGPoint(x: snappedX, y: snappedY)
        }
    }
}

#if DEBUG
struct FloatingToolButton_Previews: PreviewProvider {
    static var previews: some View {
        FloatingToolButton(
            position: .constant(CGPoint(x: 200, y: 200)),
            isToolPickerPresented: .constant(false),
            action: {}
        )
        .previewLayout(.sizeThatFits)
    }
}
#endif
