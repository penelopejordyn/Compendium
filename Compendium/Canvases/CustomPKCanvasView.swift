import SwiftUI
import PencilKit
import UIKit

// MARK: - SwiftUI Wrapper
struct CustomPKCanvasView: UIViewControllerRepresentable {
    @Binding var drawing: PKDrawing
    var tool: DrawingTool
    var color: Color
    var lineWidth: CGFloat
    @Binding var showToolPicker: Bool
    @Binding var canvasOffset: CGPoint
    @Binding var canvasScale: CGFloat
    @Binding var isRulerActive: Bool
    @Binding var allowFingerDrawing: Bool
    var lastDrawingPoint: ((CGPoint) -> Void)
    var canvasSizeUpdated: ((CGSize) -> Void)?
    let initialOffset: CGPoint
    let initialScale: CGFloat
    let isNewChalkboard: Bool
    let chalkboardId: UUID
    let isCard: Bool
    let viewController: ((CustomCanvasViewController) -> Void)?
    
    func makeUIViewController(context: Context) -> CustomCanvasViewController {
        let viewController = CustomCanvasViewController()
        viewController.drawing = drawing
        viewController.drawingChanged = { newDrawing in
            drawing = newDrawing
        }
        viewController.pencilDoubleTapped = {
            showToolPicker.toggle()
        }
        viewController.lastDrawingPoint = lastDrawingPoint
        viewController.scrollUpdated = { offset, scale in
            canvasOffset = offset
            canvasScale = scale
        }
        
        viewController.initialOffset = initialOffset
        viewController.initialScale = initialScale
        viewController.isNewChalkboard = isNewChalkboard
        viewController.chalkboardId = chalkboardId
        viewController.isCard = isCard
        
        // Configure canvas drawing policy
        viewController.canvasView.drawingPolicy = allowFingerDrawing ? .anyInput : .pencilOnly
        
        self.viewController?(viewController)
        
        return viewController
    }
    
    func updateUIViewController(_ viewController: CustomCanvasViewController, context: Context) {
        if viewController.chalkboardId == chalkboardId {
            viewController.drawing = drawing
            viewController.updateTool(tool: tool, color: color, width: lineWidth)
            viewController.canvasView.isRulerActive = isRulerActive
            viewController.canvasView.drawingPolicy = allowFingerDrawing ? .anyInput : .pencilOnly
        }
    }
}

// MARK: - View Controller
class CustomCanvasViewController: UIViewController {
    // MARK: - Properties
    let canvasView = PKCanvasView()
    let maxContentEdge: CGFloat = 900000
    
    var drawing: PKDrawing {
        get { canvasView.drawing }
        set { canvasView.drawing = newValue }
    }
    
    var isCard: Bool = false
    var isNewChalkboard: Bool = false
    var initialOffset: CGPoint = .zero
    var initialScale: CGFloat = 1.0
    var chalkboardId: UUID = UUID()
    
    private var hasRestoredPosition = false
    private var visibleTiles: Set<TileRect> = []
    private let tileSize: CGFloat = 100
    
    // Callbacks
    var drawingChanged: ((PKDrawing) -> Void)?
    var pencilDoubleTapped: (() -> Void)?
    var lastDrawingPoint: ((CGPoint) -> Void)?
    var scrollUpdated: ((CGPoint, CGFloat) -> Void)?
    var canvasSizeUpdated: ((CGSize) -> Void)?
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCanvasView()
        setupPencilInteraction()
        setupNotifications()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !hasRestoredPosition {
            restoreCanvasPosition()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup Methods
    private func setupCanvasView() {
        canvasView.backgroundColor = isCard ? .clear : UIColor(red: 0.0353, green: 0.0431, blue: 0.0784, alpha: 1.0)
        
        // Configure basic canvas view properties
        canvasView.isMultipleTouchEnabled = true
        
        view.addSubview(canvasView)
        
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            canvasView.topAnchor.constraint(equalTo: view.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Configure canvas properties
        canvasView.delegate = self
        
        // Configure scrolling and zooming
        canvasView.maximumZoomScale = 5.0
        canvasView.minimumZoomScale = 0.1
        canvasView.bouncesZoom = false
        
        // Enable infinite scrolling
        canvasView.alwaysBounceHorizontal = false
        canvasView.alwaysBounceVertical = false
        canvasView.showsHorizontalScrollIndicator = false
        canvasView.showsVerticalScrollIndicator = false
        
        // Set up infinite canvas size
        canvasView.contentSize = CGSize(width: maxContentEdge, height: maxContentEdge)
        
        // Set up pan gesture recognizer for two-finger panning
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.minimumNumberOfTouches = 2
        panGesture.maximumNumberOfTouches = 2
        panGesture.delegate = self
        canvasView.addGestureRecognizer(panGesture)
        
        // Add double-tap gesture for resetting zoom
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        canvasView.addGestureRecognizer(doubleTapGesture)
    }
    
    private func setupPencilInteraction() {
        let interaction = UIPencilInteraction()
        interaction.delegate = self
        view.addInteraction(interaction)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOrientationChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }
    
    // MARK: - Canvas Management
    private func restoreCanvasPosition() {
        if isNewChalkboard {
            centerContent()
        } else {
            canvasView.zoomScale = initialScale
            canvasView.contentOffset = initialOffset
        }
        
        hasRestoredPosition = true
        scrollUpdated?(canvasView.contentOffset, canvasView.zoomScale)
        NotificationCenter.default.post(
            name: .init("ZoomChanged"),
            object: nil,
            userInfo: ["scale": canvasView.zoomScale]
        )
    }
    
    private func centerContent() {
        let centerOffset = CGPoint(
            x: (maxContentEdge - view.bounds.width) / 2,
            y: (maxContentEdge - view.bounds.height) / 2
        )
        canvasView.contentOffset = centerOffset
        scrollUpdated?(centerOffset, canvasView.zoomScale)
    }
    
    // MARK: - Tool Management
    func updateTool(tool: DrawingTool, color: Color, width: CGFloat) {
        switch tool {
        case .lasso:
            canvasView.tool = PKLassoTool()
            
        case .eraser:
            canvasView.tool = PKEraserTool(.bitmap, width: width)
            
        case .crayon, .brush, .highlighter:
            let ink: PKInk
            let uiColor = tool == .highlighter ? 
            UIColor(color).withAlphaComponent(0.3) : 
            UIColor(color)
            
            switch tool {
            case .crayon:
                ink = PKInk(.pencil, color: uiColor)
            case .brush:
                ink = PKInk(.pen, color: uiColor)
            case .highlighter:
                ink = PKInk(.marker, color: uiColor)
            default:
                return
            }
            
            canvasView.tool = PKInkingTool(ink: ink, width: width)
        }
    }
    
    // MARK: - Gesture Handlers
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .changed:
            let translation = gesture.translation(in: canvasView)
            let newOffset = CGPoint(
                x: canvasView.contentOffset.x - translation.x,
                y: canvasView.contentOffset.y - translation.y
            )
            canvasView.contentOffset = newOffset
            gesture.setTranslation(.zero, in: canvasView)
            scrollUpdated?(newOffset, canvasView.zoomScale)
        default:
            break
        }
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        UIView.animate(withDuration: 0.3) {
            self.canvasView.zoomScale = 1.0
            self.centerContent()
        }
    }
    
    @objc private func handleOrientationChange() {
        DispatchQueue.main.async {
            self.updateVisibleTiles()
        }
    }
    
    // MARK: - Tile Management
    private func updateVisibleTiles() {
        let visibleRect = CGRect(
            origin: canvasView.contentOffset,
            size: canvasView.bounds.size
        ).insetBy(dx: -tileSize, dy: -tileSize)
        
        let minX = floor(visibleRect.minX / tileSize) * tileSize
        let minY = floor(visibleRect.minY / tileSize) * tileSize
        let maxX = ceil(visibleRect.maxX / tileSize) * tileSize
        let maxY = ceil(visibleRect.maxY / tileSize) * tileSize
        
        var newTiles: Set<TileRect> = []
        
        for x in stride(from: minX, to: maxX, by: tileSize) {
            for y in stride(from: minY, to: maxY, by: tileSize) {
                let tileRect = CGRect(x: x, y: y, width: tileSize, height: tileSize)
                newTiles.insert(TileRect(rect: tileRect))
            }
        }
        
        visibleTiles = newTiles
    }
}

// MARK: - Protocol Extensions
extension CustomCanvasViewController: PKCanvasViewDelegate {
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        drawingChanged?(canvasView.drawing)
        
        if let lastStroke = canvasView.drawing.strokes.last {
            let strokeBounds = lastStroke.renderBounds
            let location = CGPoint(
                x: strokeBounds.maxX,
                y: strokeBounds.maxY
            )
            lastDrawingPoint?(location)
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateVisibleTiles()
        scrollUpdated?(scrollView.contentOffset, scrollView.zoomScale)
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        NotificationCenter.default.post(
            name: .init("ZoomChanged"),
            object: nil,
            userInfo: ["scale": scrollView.zoomScale]
        )
        scrollUpdated?(scrollView.contentOffset, scrollView.zoomScale)
    }
}

extension CustomCanvasViewController: UIPencilInteractionDelegate {
    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        DispatchQueue.main.async {
            self.pencilDoubleTapped?()
        }
    }
}

extension CustomCanvasViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // Allow simultaneous gestures for better interaction
        return true
    }
}

// MARK: - Supporting Types
struct TileRect: Hashable {
    let rect: CGRect
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(rect.origin.x)
        hasher.combine(rect.origin.y)
        hasher.combine(rect.size.width)
        hasher.combine(rect.size.height)
    }
    
    static func == (lhs: TileRect, rhs: TileRect) -> Bool {
        return lhs.rect == rhs.rect
    }
}
