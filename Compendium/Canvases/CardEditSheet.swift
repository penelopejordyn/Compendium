import SwiftUI
import PencilKit

struct CardEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var card: Card
    
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
    
    // Zoom and Pan State
    @State private var currentScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var currentPosition: CGSize = .zero
    @State private var lastPosition: CGSize = .zero
    
    init(card: Binding<Card>) {
        self._card = card
        self._drawing = State(initialValue: card.wrappedValue.drawing)
        
        // Position button in top right
        self._toolButtonPosition = State(initialValue: calculateDefaultToolButtonPosition())
    }
    
    private func calculateDefaultToolButtonPosition() -> CGPoint {
        let screenBounds = UIScreen.main.bounds
        let safeArea = UIApplication.shared.connectedScenes
            .filter { $0 is UIWindowScene }
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .first?.safeAreaInsets ?? .zero
        
        return CGPoint(
            x: screenBounds.width - 60 - safeArea.right,
            y: 60 + safeArea.top
        )
    }    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                // Card Container with Zoom and Pan
                ZStack {
                    // Card Canvas
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(card.backgroundColor)
                            .opacity(card.opacity)
                        
                        if card.background.style != .none {
                            CardBackgroundView(
                                background: card.background,
                                size: card.size
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        CustomPKCanvasView(
                            drawing: $drawing,
                            tool: selectedTool,
                            color: color,
                            lineWidth: lineWidth,
                            showToolPicker: $isToolPickerPresented,
                            canvasOffset: $canvasOffset,
                            canvasScale: $canvasScale,
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
                    .frame(width: card.size.width, height: card.size.height)
                    
                    // Tool Popover
                    if isToolPickerPresented {
                        PopoverView(
                            isPresented: $isToolPickerPresented,
                            position: $toolPosition,
                            dragOffset: $dragOffset,
                            selectedTool: $selectedTool,
                            color: $color,
                            lineWidth: $lineWidth,
                            cards: .constant([]),
                            canvasOffset: $canvasOffset,
                            canvasScale: $canvasScale,
                            isRulerActive: $isRulerActive,
                            isPositionLocked: $isToolPositionLocked,
                            allowFingerDrawing: $allowFingerDrawing
                        )
                    }
                }
                .scaleEffect(currentScale)
                .offset(x: currentPosition.width, y: currentPosition.height)
                .position(
                    x: geometry.size.width / 2,
                    y: geometry.size.height / 2
                )
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                let newScale = currentScale * delta
                                currentScale = min(max(newScale, 0.5), 5.0)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                            },
                        DragGesture()
                            .onChanged { value in
                                let delta = CGSize(
                                    width: value.translation.width - lastPosition.width,
                                    height: value.translation.height - lastPosition.height
                                )
                                lastPosition = value.translation
                                currentPosition.width += delta.width
                                currentPosition.height += delta.height
                            }
                            .onEnded { _ in
                                lastPosition = .zero
                            }
                    )
                )
                
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
            ToolbarItem(placement: .navigationBarLeading) {
                if horizontalSizeClass == .compact {
                    Button("Done") {
                        dismiss()
                    }
                } else {
                    Button("Close") {
                        dismiss()
                    }
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
            CardSizeEditor(size: $card.size)
        }
        .sheet(isPresented: $showBackgroundSettings) {
            NavigationView {
                CardBackgroundSettings(background: $card.background)
                    .navigationBarItems(trailing: Button("Done") {
                        showBackgroundSettings = false
                    })
            }
        }
        .popover(isPresented: $showingColorPicker) {
            ColorPicker(
                "Background Color",
                selection: $card.backgroundColor,
                supportsOpacity: true
            )
            .padding()
        }
        .onChange(of: drawing) { _, newDrawing in
            card.drawing = newDrawing
        }
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
            let screenX = ((lastDrawingPoint.x - 150) * canvasScale) - canvasOffset.x
            let screenY = (lastDrawingPoint.y * canvasScale) - canvasOffset.y
            
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
}

struct CardSizeEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var size: CGSize
    @State private var width: Double
    @State private var height: Double
    
    init(size: Binding<CGSize>) {
        self._size = size
        self._width = State(initialValue: size.wrappedValue.width)
        self._height = State(initialValue: size.wrappedValue.height)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Dimensions") {
                    HStack {
                        Text("Width")
                        Spacer()
                        TextField("Width", value: $width, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Height")
                        Spacer()
                        TextField("Height", value: $height, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .frame(width: 100)
                    }
                }
                
                Section {
                    Button("Reset to Default") {
                        width = 300
                        height = 200
                    }
                }
            }
            .navigationTitle("Card Size")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        size = CGSize(
                            width: max(100, width),
                            height: max(100, height)
                        )
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
