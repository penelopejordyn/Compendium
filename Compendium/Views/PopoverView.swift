import SwiftUI
import PencilKit

enum PopoverTab {
    case tools
    case cards
}

struct PopoverView: View {
    @Binding var isPresented: Bool
    @Binding var position: CGPoint
    @Binding var dragOffset: CGSize
    @Binding var selectedTool: DrawingTool
    @Binding var color: Color
    @Binding var lineWidth: CGFloat
    @Binding var cards: [Card]
    @Binding var canvasOffset: CGPoint
    @Binding var canvasScale: CGFloat
    @Binding var isRulerActive: Bool
    @Binding var isPositionLocked: Bool
    @Binding var allowFingerDrawing: Bool
    
    var onNavigateToCard: ((Card) -> Void)?
    
    @State private var showColorPicker = false
    @State private var currentTab = PopoverTab.tools
    @State private var editingCard: Card?
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 24), count: 3)
    private let backgroundColor = Color(UIColor.systemBackground)
    private let colorOptions: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple, .pink, .white
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            // Tab Selection
            HStack {
                Button {
                    withAnimation { currentTab = .tools }
                } label: {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Tools")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(currentTab == .tools ? Color.secondary.opacity(0.2) : Color.clear)
                    .cornerRadius(8)
                }
                
                Button {
                    withAnimation { currentTab = .cards }
                } label: {
                    HStack {
                        Image(systemName: "rectangle.stack")
                        Text("Cards")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(currentTab == .cards ? Color.secondary.opacity(0.2) : Color.clear)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 8)
            .buttonStyle(.plain)
            
            // Content based on selected tab
            ScrollView(showsIndicators: false) {
                if currentTab == .tools {
                    toolsContent
                } else {
                    cardsContent
                }
            }
        }
        .frame(width: 320, height: 500)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        )
        .offset(dragOffset)
        .position(position)
        .gesture(
            !isPositionLocked ? DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    position = CGPoint(
                        x: position.x + value.translation.width,
                        y: position.y + value.translation.height
                    )
                    dragOffset = .zero
                } : nil
        )
        .sheet(item: $editingCard) { card in
            NavigationStack {
                CardEditorView(card: getCardBinding(for: card))
            }
        }
    }
    
    private var toolsContent: some View {
        VStack(spacing: 24) {
            // Tools Grid
            VStack(alignment: .leading, spacing: 16) {
                Text("Tools")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                
                LazyVGrid(columns: columns, spacing: 24) {
                    toolButton(tool: .crayon, icon: "pencil", label: "Chalk")
                    toolButton(tool: .brush, icon: "paintbrush.pointed", label: "Brush")
                    toolButton(tool: .highlighter, icon: "highlighter", label: "Marker")
                    toolButton(tool: .eraser, icon: "eraser", label: "Eraser")
                    toolButton(tool: .lasso, icon: "lasso", label: "Select")
                    
                    Button {
                        addNewCard()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "plus.rectangle")
                                .font(.system(size: 24))
                                .foregroundStyle(.primary)
                            Text("Add Card")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            Divider()
                .padding(.horizontal, -16)
            
            // Settings Toggles
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                
                VStack(spacing: 12) {
                    Toggle(isOn: $isPositionLocked) {
                        Label("Lock Position", systemImage: "lock")
                            .foregroundColor(.primary)
                    }
                    
                    Toggle(isOn: $allowFingerDrawing) {
                        Label("Allow Finger Drawing", systemImage: "hand.point.up.left")
                            .foregroundColor(.primary)
                    }
                    
                    Toggle("Ruler", isOn: $isRulerActive)
                        .foregroundColor(.primary)
                }
            }
            
            if selectedTool != .eraser && selectedTool != .lasso {
                Divider()
                    .padding(.horizontal, -16)
                
                // Colors
                VStack(alignment: .leading, spacing: 16) {
                    Text("Colors")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                        ForEach(colorOptions, id: \.self) { colorOption in
                            colorButton(for: colorOption)
                        }
                        
                        Button {
                            showColorPicker.toggle()
                        } label: {
                            ZStack {
                                Circle()
                                    .stroke(.quaternary, lineWidth: 1)
                                    .frame(width: 32, height: 32)
                                Image(systemName: "plus")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .popover(isPresented: $showColorPicker) {
                            ColorPicker("", selection: $color, supportsOpacity: false)
                                .labelsHidden()
                                .padding(8)
                        }
                    }
                }
                
                Divider()
                    .padding(.horizontal, -16)
                
                // Size Slider
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Size")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(lineWidth))")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)
                    
                    HStack {
                        Image(systemName: "minus")
                            .foregroundStyle(.secondary)
                        Slider(value: $lineWidth, in: 1...50)
                            .tint(.primary)
                        Image(systemName: "plus")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
    }
    
    private var cardsContent: some View {
        LazyVStack(spacing: 16) {
            ForEach(cards) { card in
                cardPreview(for: card)
            }
            
            if cards.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No Cards")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Add cards using the + button in the Tools tab")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }
        }
        .padding(16)
    }
    
    // MARK: - Helper Views
    
    private func toolButton(tool: DrawingTool, icon: String, label: String) -> some View {
        Button {
            selectedTool = tool
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(selectedTool == tool ? (color) : .primary)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            Color.secondary
                .opacity(selectedTool == tool ? 0.2 : 0)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func colorButton(for colorOption: Color) -> some View {
        Button {
            color = colorOption
        } label: {
            Circle()
                .fill(colorOption)
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(color == colorOption ? Color.primary : Color.secondary,
                                lineWidth: color == colorOption ? 2 : 1)
                )
        }
    }
    
    private func cardPreview(for card: Card) -> some View {
        Button {
            navigateToCard(card)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
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
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button {
                editingCard = card
            } label: {
                Label("Edit Card", systemImage: "pencil")
            }
            
            Button {
                toggleCardLock(card)
            } label: {
                Label(card.isLocked ? "Unlock Card" : "Lock Card", 
                      systemImage: card.isLocked ? "lock.open" : "lock")
            }
            
            Button {
                navigateToCard(card)
            } label: {
                Label("Go to Card", systemImage: "arrow.right")
            }
            
            Button(role: .destructive) {
                deleteCard(card)
            } label: {
                Label("Delete Card", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCardBinding(for card: Card) -> Binding<Card> {
        Binding(
            get: { card },
            set: { newValue in
                if let index = cards.firstIndex(where: { $0.id == card.id }) {
                    cards[index] = newValue
                }
            }
        )
    }
    
    private func navigateToCard(_ card: Card) {
        onNavigateToCard?(card)
    }
    
    private func deleteCard(_ card: Card) {
        cards.removeAll { $0.id == card.id }
    }
    
    private func addNewCard() {
        let screenCenter = CGPoint(
            x: UIScreen.main.bounds.width / 2,
            y: UIScreen.main.bounds.height / 2
        )
        
        let canvasPosition = CGPoint(
            x: (screenCenter.x + canvasOffset.x) / canvasScale,
            y: (screenCenter.y + canvasOffset.y) / canvasScale
        )
        
        let newCard = Card(
            position: canvasPosition,
            backgroundColor: Color(red: 1, green: 0.2157, blue: 0.3725, opacity: 0.67)
        )
        
        cards.append(newCard)
        currentTab = .cards
    }
    
    private func toggleCardLock(_ card: Card) {
        if let index = cards.firstIndex(where: { $0.id == card.id }) {
            cards[index].isLocked.toggle()
        }
    }
}

#Preview {
    PopoverView(
        isPresented: .constant(true),
        position: .constant(CGPoint(x: 200, y: 200)),
        dragOffset: .constant(.zero),
        selectedTool: .constant(.crayon),
        color: .constant(.red),
        lineWidth: .constant(2),
        cards: .constant([]),
        canvasOffset: .constant(.zero),
        canvasScale: .constant(1.0),
        isRulerActive: .constant(false),
        isPositionLocked: .constant(false),
        allowFingerDrawing: .constant(false)
    )
}
