import SwiftUI
import PencilKit

struct UnassignedCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject var store: ChalkboardStore
    @Environment(\.presentationMode) private var presentationMode
    
    let card: Card
    
    // Drawing and Tool State
    @State private var drawing: PKDrawing
    @State private var selectedTool: DrawingTool = .crayon
    @State private var color: Color = Color(red: 1, green: 0.2157, blue: 0.3725)
    @State private var lineWidth: CGFloat = 10
    @State private var isToolPickerPresented = false
    @State private var toolPosition: CGPoint = CGPoint(x: UIScreen.main.bounds.width/2,
                                                       y: UIScreen.main.bounds.height/2)
    @State private var dragOffset = CGSize.zero
    @State private var toolButtonPosition = CGPoint(x: UIScreen.main.bounds.width - 60, 
                                                    y: UIScreen.main.bounds.height - 100)
    @State private var lastDrawingPoint: CGPoint = .zero
    @State private var isToolPositionLocked = false
    @State private var allowFingerDrawing = false
    
    // Canvas State
    @State private var canvasOffset: CGPoint = .zero
    @State private var canvasScale: CGFloat = 1.0
    @State private var isRulerActive: Bool = false
    @State private var showingSizeEditor = false
    @State private var showBackgroundSettings = false
    @State private var showingColorPicker = false
    
    // Card State
    @State private var cardSize: CGSize
    @State private var cardBackground: CardBackground
    @State private var cardBackgroundColor: Color
    @State private var cardOpacity: Double
    
    init(card: Card) {
        self.card = card
        _drawing = State(initialValue: card.drawing)
        _cardSize = State(initialValue: card.size)
        _cardBackground = State(initialValue: card.background)
        _cardBackgroundColor = State(initialValue: card.backgroundColor)
        _cardOpacity = State(initialValue: card.opacity)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                // Card Container with Zoom and Pan
                ZStack {
                    // Card Canvas
                    cardContent
                        .scaleEffect(canvasScale)
                        .offset(x: canvasOffset.x, y: canvasOffset.y)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        canvasScale = value * canvasScale
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        canvasOffset = CGPoint(
                                            x: canvasOffset.x + value.translation.width,
                                            y: canvasOffset.y + value.translation.height
                                        )
                                    }
                            )
                        )
                    
                    // Tool Popover
                    if isToolPickerPresented {
                        PopoverView(
                            isPresented: $isToolPickerPresented,
                            position: $toolPosition,
                            dragOffset: $dragOffset,
                            selectedTool: $selectedTool,
                            color: $color,
                            lineWidth: $lineWidth,
                            cards: .constant([]), // Unassigned card doesn't have sub-cards
                            canvasOffset: $canvasOffset,
                            canvasScale: $canvasScale,
                            isRulerActive: $isRulerActive,
                            isPositionLocked: $isToolPositionLocked,
                            allowFingerDrawing: $allowFingerDrawing
                        )
                    }
                }
                
                // Floating Tool Button
                FloatingToolButton(
                    position: Binding(
                        get: { 
                            // Ensure position is within screen bounds
                            CGPoint(
                                x: min(max(toolButtonPosition.x, 40), geometry.size.width - 40),
                                y: min(max(toolButtonPosition.y, 40 + geometry.safeAreaInsets.top), 
                                       geometry.size.height - 40)
                            )
                        },
                        set: { newValue in
                            toolButtonPosition = newValue
                        }
                    ),
                    isToolPickerPresented: $isToolPickerPresented
                ) {
                    toggleToolPicker()
                }
                .ignoresSafeArea(.keyboard)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    saveAndDismiss()
                }
            }
            ToolbarItem(placement: .principal) {
                Menu {
                    Button {
                        showingSizeEditor = true
                    } label: {
                        Label("Edit Size", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                    
                    Button {
                        showBackgroundSettings = true
                    } label: {
                        Label("Background Settings", systemImage: "square.grid.2x2")
                    }
                    
                    Button {
                        showingColorPicker = true
                    } label: {
                        Label("Change Color", systemImage: "paintpalette")
                    }
                    
                    Button(role: .destructive) {
                        drawing = PKDrawing()
                    } label: {
                        Label("Clear Canvas", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingSizeEditor) {
            CardSizeEditor(size: $cardSize)
        }
        .sheet(isPresented: $showBackgroundSettings) {
            NavigationView {
                CardBackgroundSettings(background: $cardBackground)
                    .navigationBarItems(trailing: Button("Done") {
                        showBackgroundSettings = false
                    })
            }
        }
        .popover(isPresented: $showingColorPicker) {
            ColorPicker(
                "Background Color",
                selection: $cardBackgroundColor,
                supportsOpacity: true
            )
            .padding()
        }
    }
    
    private var cardContent: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(cardBackgroundColor)
                .opacity(cardOpacity)
            
            if cardBackground.style != .none {
                CardBackgroundView(
                    background: cardBackground,
                    size: cardSize
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            CustomPKCanvasView(
                drawing: $drawing,
                tool: selectedTool,
                color: color,
                lineWidth: lineWidth,
                showToolPicker: $isToolPickerPresented,
                canvasOffset: .constant(.zero), // Card-specific offset
                canvasScale: .constant(1.0), // Card-specific scale
                isRulerActive: $isRulerActive,
                allowFingerDrawing: $allowFingerDrawing,
                lastDrawingPoint: { point in
                    lastDrawingPoint = point
                    updateToolPosition(point)
                },
                canvasSizeUpdated: nil,
                initialOffset: .zero,
                initialScale: 1.0,
                isNewChalkboard: false,
                chalkboardId: card.id,
                isCard: true,
                viewController: nil
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(width: cardSize.width, height: cardSize.height)
    }
    
    private func toggleToolPicker() {
        if isToolPickerPresented {
            isToolPickerPresented = false
        } else {
            let popoverPosition = calculatePopoverPosition()
            toolPosition = popoverPosition
            isToolPickerPresented = true
        }
    }
    
    private func calculatePopoverPosition() -> CGPoint {
        let screenBounds = UIScreen.main.bounds
        
        if lastDrawingPoint != .zero {
            let screenX = ((lastDrawingPoint.x - 150) * canvasScale) + canvasOffset.x
            let screenY = (lastDrawingPoint.y * canvasScale) + canvasOffset.y
            
            let x = max(150, min(screenX, screenBounds.width - 150))
            let y = max(150, min(screenY, screenBounds.height - 150))
            
            return CGPoint(x: x, y: y)
        }
        
        return toolButtonPosition
    }
    
    private func updateToolPosition(_ point: CGPoint) {
        lastDrawingPoint = point
        if isToolPickerPresented && !isToolPositionLocked {
            let screenPosition = calculatePopoverPosition()
            withAnimation(.easeInOut(duration: 0.2)) {
                toolPosition = screenPosition
            }
        }
    }
    
    private func saveAndDismiss() {
        var updatedCard = card
        updatedCard.drawing = drawing
        updatedCard.size = cardSize
        updatedCard.background = cardBackground
        updatedCard.backgroundColor = cardBackgroundColor
        updatedCard.opacity = cardOpacity
        
        store.updateUnassignedCard(updatedCard)
        dismiss()
         presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    NavigationView {
        UnassignedCardView(card: Card())
            .environmentObject(ChalkboardStore())
    }
}
