import SwiftUI
import PencilKit
import UIKit

class CardPKCanvasView: PKCanvasView {
    var isEditing: Bool = false {
        didSet {
            // Instead of disabling user interaction entirely, we'll override hit testing
            self.isUserInteractionEnabled = true
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // If we're not in edit mode, don't capture touch events - let them pass through
        if !isEditing {
            return nil
        }
        
        // If we are in edit mode, handle touches normally
        return super.hitTest(point, with: event)
    }
}

struct PKCardCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var tool: DrawingTool
    var color: Color
    var lineWidth: CGFloat
    var isEditing: Bool
    var cardId: UUID
    
    func makeUIView(context: Context) -> CardPKCanvasView {
        let canvasView = CardPKCanvasView()
        canvasView.drawing = drawing
        canvasView.backgroundColor = .clear
        canvasView.isScrollEnabled = false
        canvasView.delegate = context.coordinator
        canvasView.isEditing = isEditing
        
        // Always use pencil-only drawing policy
        canvasView.drawingPolicy = .pencilOnly
        
        updateTool(canvasView)
        return canvasView
    }
    
    func updateUIView(_ canvasView: CardPKCanvasView, context: Context) {
        // Update drawing if changed
        if canvasView.drawing != drawing {
            canvasView.drawing = drawing
        }
        
        // Update edit state
        canvasView.isEditing = isEditing
        
        // Update drawing tool
        updateTool(canvasView)
    }
    
    private func updateTool(_ canvasView: CardPKCanvasView) {
        switch tool {
        case .lasso:
            canvasView.tool = PKLassoTool()
        case .eraser:
            canvasView.tool = PKEraserTool(.bitmap, width: lineWidth)
        case .crayon, .brush, .highlighter:
            let ink: PKInk
            switch tool {
            case .crayon:
                ink = PKInk(.pencil, color: UIColor(color))
            case .brush:
                ink = PKInk(.pen, color: UIColor(color))
            case .highlighter:
                ink = PKInk(.marker, color: UIColor(color).withAlphaComponent(0.3))
            default:
                fatalError("This case should never be reached")
            }
            canvasView.tool = PKInkingTool(ink: ink, width: lineWidth)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing)
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var drawing: Binding<PKDrawing>
        
        init(drawing: Binding<PKDrawing>) {
            self.drawing = drawing
            super.init()
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawing.wrappedValue = canvasView.drawing
        }
    }
}

#if DEBUG
struct PKCardCanvasView_Previews: PreviewProvider {
    static var previews: some View {
        PKCardCanvasView(
            drawing: .constant(PKDrawing()),
            tool: .crayon,
            color: .red,
            lineWidth: 2,
            isEditing: false,
            cardId: UUID()
        )
        .frame(width: 300, height: 200)
        .previewLayout(.sizeThatFits)
    }
}
#endif
