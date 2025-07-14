import SwiftUI
import PencilKit

// MARK: - ChalkboardView
struct ChalkboardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject var store: ChalkboardStore
    let chalkboard: Chalkboard
    
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
    @State private var currentRotation: Double = 0
    @State private var currentZoom: CGFloat = 1.0
    @State private var cards: [Card]
    @State private var canvasOffset: CGPoint
    @State private var canvasScale: CGFloat
    @State private var canvasState: (offset: CGPoint, scale: CGFloat) = (.zero, 1.0)
    @State private var activeCard: UUID? = nil
    @State private var isRulerActive: Bool = false
    
    // UI State
    @State private var currentContent: SidePanelContent = .chalkboards
    @State private var isCardListVisible = false
    @State private var viewController: CustomCanvasViewController?
    
    // Autosave State
    @State private var hasUnsavedChanges: Bool = false
    @State private var autoSaveTimer: Timer? = nil
    private let autoSaveInterval: TimeInterval = 600 // 10 minutes in seconds
    
    private let chalkboardColor = Color(red: 0.0353, green: 0.0431, blue: 0.0784)
    
    init(chalkboard: Chalkboard) {
        self.chalkboard = chalkboard
        _cards = State(initialValue: chalkboard.cards)
        
        let isNewChalkboard = chalkboard.drawing.bounds.isEmpty && chalkboard.cards.isEmpty
        let centerOffset = isNewChalkboard ?
        CGPoint(x: 450000, y: 450000) :
        (chalkboard.canvasOffset == .zero ? CGPoint(x: 450000, y: 450000) : chalkboard.canvasOffset)
        
        _drawing = State(initialValue: chalkboard.drawing)
        _cards = State(initialValue: chalkboard.cards)
        _canvasOffset = State(initialValue: centerOffset)
        _canvasScale = State(initialValue: chalkboard.zoomScale > 0 ? chalkboard.zoomScale : 1.0)
    }
    
    var body: some View {
        mainContent
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if horizontalSizeClass == .compact {
                    ToolbarItem(placement: .principal) {
                        Text(chalkboard.name)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                }
            }
            .onAppear {
                setupAutoSave()
            }
            .onDisappear {
                stopAutoSave()
                // Save any pending changes when view disappears
                if hasUnsavedChanges {
                    saveChalkboardState()
                }
            }
            .onChange(of: chalkboard.cards) { _, newCards in
                cards = newCards
            }
            .onReceive(store.objectWillChange) { _ in
                if let updatedChalkboard = store.chalkboards.first(where: { $0.id == chalkboard.id }) {
                    cards = updatedChalkboard.cards
                }
            }
    }
    
    private var mainContent: some View {
        ZStack {
            HStack(spacing: 0) {
                ZStack {
                    canvasLayer
                    cardsLayer
                    statusOverlay
                    cardPanel
                    toolPicker
                }
            }
            .navigationBarBackButtonHidden(horizontalSizeClass == .regular)
            .edgesIgnoringSafeArea(.all)
            .background(chalkboardColor.edgesIgnoringSafeArea(.all))
            .contentShape(Rectangle())
            .onTapGesture(perform: handleCanvasTap)
            
            FloatingToolButton(
                position: $toolButtonPosition,
                isToolPickerPresented: $isToolPickerPresented
            ) {
                toggleToolPicker()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("ZoomChanged")), perform: handleZoomChange)
        .onChange(of: drawing) { _, _ in markUnsavedChanges() }
        .onChange(of: cards) { _, _ in markUnsavedChanges() }
        .onChange(of: canvasOffset) { _, newOffset in
            canvasState.offset = newOffset
            markUnsavedChanges()
        }
        .onChange(of: canvasScale) { _, newScale in
            currentZoom = newScale
            canvasState.scale = newScale
            markUnsavedChanges()
        }
    }
    
    private var canvasLayer: some View {
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
            canvasSizeUpdated: nil,  // Changed from isCard
            initialOffset: canvasOffset,
            initialScale: canvasScale,
            isNewChalkboard: chalkboard.drawing.bounds.isEmpty && chalkboard.cards.isEmpty,
            chalkboardId: chalkboard.id,
            isCard: false,  // Moved here
            viewController: { controller in
                viewController = controller
            }
        )
        .allowsHitTesting(activeCard == nil)
        .id(chalkboard.id)
    }
    
    private var cardsLayer: some View {
        ForEach($cards) { $card in
            CardView(
                card: $card,
                tool: selectedTool,
                color: color,
                lineWidth: lineWidth,
                onDelete: { deleteCard(card.id) },
                canvasOffset: $canvasOffset,
                canvasScale: $canvasScale
            )
            .onTapGesture {
                handleCardTap(cardId: card.id)
            }
        }
    }
    
    private var statusOverlay: some View {
        VStack {
            HStack(spacing: 12) {
                Text("Zoom: \(Int(currentZoom * 100))%")
                    .padding(8)
                    .background(Color.black.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                Spacer()
                
                if horizontalSizeClass == .regular {
                    Button {
                        isCardListVisible.toggle()
                    } label: {
                        Image(systemName: "rectangle.stack")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
            Spacer()
        }
    }
    
    private var cardPanel: some View {
        Group {
            if currentContent == .cards || isCardListVisible {
                CardPanel(
                    isVisible: $isCardListVisible,
                    cards: $cards,
                    canvasOffset: $canvasOffset,
                    canvasScale: $canvasScale,
                    onCardDeleted: deleteCard
                )
            }
        }
    }
    
    private var toolPicker: some View {
        Group {
            if isToolPickerPresented {
                PopoverView(
                    isPresented: $isToolPickerPresented,
                    position: $toolPosition,
                    dragOffset: $dragOffset,
                    selectedTool: $selectedTool,
                    color: $color,
                    lineWidth: $lineWidth,
                    cards: $cards,
                    canvasOffset: $canvasOffset,
                    canvasScale: $canvasScale,
                    isRulerActive: $isRulerActive,
                    isPositionLocked: $isToolPositionLocked,
                    allowFingerDrawing: $allowFingerDrawing,
                    onNavigateToCard: { card in
                        navigateToCard(card)
                    }
                )
            }
        }
    }
    
    // MARK: - Tool Management
    private func showToolPicker() {
        if !isToolPickerPresented {
            let popoverPosition = calculatePopoverPosition()
            toolPosition = popoverPosition
            isToolPickerPresented = true
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
            let screenX = ((lastDrawingPoint.x) * canvasScale) - canvasOffset.x - 250
            let screenY = ((lastDrawingPoint.y) * canvasScale) - canvasOffset.y
            
            // Keep the popover within screen bounds with padding
            let x = max(150, min(screenX, screenBounds.width - 150))
            let y = max(150, min(screenY, screenBounds.height - 150))
            
            print("Canvas Point: \(lastDrawingPoint)")
            print("Screen Position: \(x), \(y)")
            print("Canvas Offset: \(canvasOffset)")
            print("Canvas Scale: \(canvasScale)")
            
            return CGPoint(x: x, y: y)
        }
        
        // Fall back to tool button position if no drawing point
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
    
    // MARK: - Event Handlers

    @State private var isNavigatingToCard = false
    
    private func handleCanvasTap() {
        // Only reset if we're not navigating to a card
        if !isNavigatingToCard {
            activeCard = nil
            for index in cards.indices {
                cards[index].isEditing = false
            }
            // Mark changes and save to prevent state loss when deselecting cards
            markUnsavedChanges()
            saveChalkboardState()
        }
        // Reset the navigation flag after handling tap
        isNavigatingToCard = false
    }
    
    // Update the navigation function in PopoverView
    // In ChalkboardView.swift
    
    private func navigateToCard(_ card: Card) {
        isNavigatingToCard = true
        
        let screenCenter = CGPoint(
            x: UIScreen.main.bounds.width / 2,
            y: UIScreen.main.bounds.height / 2
        )
        
        // Calculate the actual position in the infinite canvas
        let targetX = card.position.x - screenCenter.x / canvasScale
        let targetY = card.position.y - screenCenter.y / canvasScale
        
        withAnimation(.easeInOut(duration: 0.3)) {
            // Update the CustomCanvasViewController's scroll position
            viewController?.canvasView.contentOffset = CGPoint(
                x: targetX * canvasScale,
                y: targetY * canvasScale
            )
            
            // Set the card as active
            activeCard = card.id
            if let index = cards.firstIndex(where: { $0.id == card.id }) {
                cards[index].isEditing = true
            }
        }
        
        // Update the stored offset
        canvasOffset = CGPoint(
            x: targetX * canvasScale,
            y: targetY * canvasScale
        )
        
        // Save the new state
        markUnsavedChanges()
        saveChalkboardState()
        isToolPickerPresented = false
    }
    
    private func handleZoomChange(_ notification: Notification) {
        if let scale = notification.userInfo?["scale"] as? CGFloat {
            currentZoom = scale
        }
    }
    
    // MARK: - Card Management
    private func handleCardTap(cardId: UUID) {
        // Find the tapped card
        if let index = cards.firstIndex(where: { $0.id == cardId }) {
            let wasEditing = cards[index].isEditing
            
            // First, exit edit mode for all cards
            for cardIndex in cards.indices {
                cards[cardIndex].isEditing = false
            }
            
            // If the tapped card wasn't editing, enter edit mode for it
            if !wasEditing {
                cards[index].isEditing = true
                activeCard = cardId
            } else {
                // If it was editing, keep it in non-edit mode
                activeCard = nil
            }
            
            // Mark changes and save immediately to prevent state loss
            markUnsavedChanges()
            saveChalkboardState()
        }
    }
    
    private func deleteCard(_ cardID: UUID) {
        if activeCard == cardID {
            activeCard = nil
        }
        cards.removeAll { $0.id == cardID }
        saveChalkboardState()
    }
    
    // MARK: - Autosave
    private func setupAutoSave() {
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: autoSaveInterval, repeats: true) { _ in
            if hasUnsavedChanges {
                saveChalkboardState()
                hasUnsavedChanges = false
            }
        }
    }
    
    private func stopAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }
    
    private func markUnsavedChanges() {
        hasUnsavedChanges = true
    }
    
    // MARK: - State Management
    private func saveChalkboardState() {
        var updatedChalkboard = chalkboard
        updatedChalkboard.drawingData = drawing.dataRepresentation()
        updatedChalkboard.cards = cards
        updatedChalkboard.canvasOffset = canvasOffset  // Always save position
        updatedChalkboard.zoomScale = canvasScale
        updatedChalkboard.lastEditDate = Date()
        
        if let image = drawing.image(
            from: drawing.bounds,
            scale: UIScreen.main.scale
        ).jpegData(compressionQuality: 0.7) {
            updatedChalkboard.previewImageData = image
        }
        
        updatedChalkboard.canvasOffset = canvasOffset
        updatedChalkboard.zoomScale = canvasScale
        
        store.updateChalkboard(updatedChalkboard)
        hasUnsavedChanges = false
    }
}
