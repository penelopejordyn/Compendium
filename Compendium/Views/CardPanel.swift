import SwiftUI
import PencilKit

/// A panel that displays a list of cards and provides navigation and editing capabilities
struct CardPanel: View {
    // MARK: - Properties
    
    // Bindings for panel state
    @Binding var isVisible: Bool
    @Binding var cards: [Card]
    @Binding var canvasOffset: CGPoint
    @Binding var canvasScale: CGFloat
    
    // Callback for card deletion
    let onCardDeleted: (UUID) -> Void
    
    // Local state for animations and interactions
    @State private var dragOffset: CGSize = .zero
    @State private var isPanelExpanded: Bool = true
    @State private var selectedCardId: UUID?
    
    // Constants for panel appearance
    private let panelWidth: CGFloat = 320
    private let cornerRadius: CGFloat = 15
    private let headerHeight: CGFloat = 44
    
    // MARK: - Body
    var body: some View {
        HStack {
            Spacer()
            
            // Main Panel Content
            VStack(spacing: 0) {
                // Header
                panelHeader
                
                if isPanelExpanded {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(cards) { card in
                                CardPreviewItem(
                                    card: card,
                                    onTap: {
                                        selectedCardId = card.id
                                        navigateToCard(card)
                                    },
                                    onColorChanged: { newColor in
                                        updateCardColor(card, newColor)
                                    },
                                    onDelete: {
                                        onCardDeleted(card.id)
                                    },
                                    onLockToggle: {
                                        toggleCardLock(card)
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .frame(width: panelWidth)
            .background(Color(UIColor.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(radius: 10)
            // Apply drag gesture for panel positioning
            .offset(dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        let translation = gesture.translation
                        // Only allow horizontal dragging
                        dragOffset = CGSize(width: translation.width, height: 0)
                    }
                    .onEnded { _ in
                        // Reset drag offset on gesture end
                        withAnimation(.spring()) {
                            dragOffset = .zero
                        }
                    }
            )
        }
        .transition(.move(edge: .trailing))
    }
    
    // MARK: - Panel Header
    private var panelHeader: some View {
        HStack {
            // Title and expand/collapse button
            Button {
                withAnimation(.spring()) {
                    isPanelExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Cards")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Image(systemName: isPanelExpanded ? "chevron.right" : "chevron.left")
                        .foregroundColor(.white)
                        .font(.system(size: 12, weight: .bold))
                }
            }
            
            Spacer()
            
            // Close button
            Button {
                withAnimation {
                    isVisible = false
                }
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
                    .font(.system(size: 12, weight: .bold))
            }
        }
        .padding()
        .frame(height: headerHeight)
        .background(Color.gray.opacity(0.3))
    }
    
    // MARK: - Card Preview Item
    private struct CardPreviewItem: View {
        let card: Card
        let onTap: () -> Void
        let onColorChanged: (Color) -> Void
        let onDelete: () -> Void
        let onLockToggle: () -> Void
        
        @State private var showingColorPicker = false
        
        var body: some View {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 8) {
                    // Card Preview
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(card.backgroundColor)
                            .opacity(card.opacity)
                        
                        if card.background.style != .none {
                            CardBackgroundView(
                                background: card.background,
                                size: CGSize(width: 320 - 32, height: 120)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        CardDrawingPreview(drawing: card.drawing)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .frame(height: 120)
                    .shadow(radius: 2)
                    
                    // Card Information
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Position: (\(Int(card.position.x)), \(Int(card.position.y)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Size: \(Int(card.size.width))×\(Int(card.size.height))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .contextMenu {
                Button {
                    onTap()
                } label: {
                    Label("Go to Card", systemImage: "arrow.forward.circle")
                }
                
                Button {
                    onLockToggle()
                } label: {
                    Label(card.isLocked ? "Unlock Card" : "Lock Card",
                          systemImage: card.isLocked ? "lock.open" : "lock")
                }
                
                Button {
                    showingColorPicker = true
                } label: {
                    Label("Change Color", systemImage: "paintpalette")
                }
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Card", systemImage: "trash")
                }
            }
            .popover(isPresented: $showingColorPicker) {
                ColorPicker(
                    "Card Color",
                    selection: Binding(
                        get: { card.backgroundColor },
                        set: { onColorChanged($0) }
                    ),
                    supportsOpacity: true
                )
                .padding()
            }
        }
    }
    
    // MARK: - Navigation Methods
    private func navigateToCard(_ card: Card) {
        // Calculate the target position for the card
        let screenCenter = CGPoint(
            x: UIScreen.main.bounds.width / 2,
            y: UIScreen.main.bounds.height / 2
        )
        let targetOffset = CGPoint(
            x: (card.position.x * canvasScale) - screenCenter.x,
            y: (card.position.y * canvasScale) - screenCenter.y
        )
        
        // Directly update the canvasOffset binding
        withAnimation(.easeInOut(duration: 0.3)) {
            canvasOffset = targetOffset
        }
    }
    
    // MARK: - Card Update Methods
    private func updateCardColor(_ card: Card, _ newColor: Color) {
        if let index = cards.firstIndex(where: { $0.id == card.id }) {
            // Update the card's color in the cards array
            cards[index].backgroundColor = newColor
        }
    }
    
    private func updateCardBackground(_ card: Card, _ newBackground: CardBackground) {
        if let index = cards.firstIndex(where: { $0.id == card.id }) {
            // Update the card's background in the cards array
            cards[index].background = newBackground
        }
    }
    
    private func toggleCardLock(_ card: Card) {
        if let index = cards.firstIndex(where: { $0.id == card.id }) {
            // Toggle the locked state of the card
            cards[index].isLocked.toggle()
        }
    }
}

// MARK: - Drawing Preview
struct CardDrawingPreview: View {
    let drawing: PKDrawing
    
    var body: some View {
        Canvas { context, size in
            let image = drawing.image(from: drawing.bounds, scale: 2.0)
            context.draw(Image(uiImage: image), in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Preview Provider
#if DEBUG
struct CardPanel_Previews: PreviewProvider {
    static var previews: some View {
        CardPanel(
            isVisible: .constant(true),
            cards: .constant([
                Card(position: .zero, backgroundColor: .red),
                Card(position: CGPoint(x: 100, y: 100), backgroundColor: .blue)
            ]),
            canvasOffset: .constant(.zero),
            canvasScale: .constant(1.0),
            onCardDeleted: { _ in }
        )
        .preferredColorScheme(.dark)
    }
}
#endif
