import SwiftUI
import PencilKit
import UIKit

struct CardView: View {
    @Binding var card: Card
    let tool: DrawingTool
    let color: Color
    let lineWidth: CGFloat
    let onDelete: () -> Void
    @Binding var canvasOffset: CGPoint
    @Binding var canvasScale: CGFloat
    
    @State private var showingColorPicker = false
    @State private var showBackgroundSettings = false
    @State private var isDragging = false
    @State private var dragOffset = CGSize.zero
    
    private var adjustedPosition: CGPoint {
        CGPoint(
            x: (card.position.x * canvasScale) - canvasOffset.x + dragOffset.width,
            y: (card.position.y * canvasScale) - canvasOffset.y + dragOffset.height
        )
    }
    
    private var cardSize: CGSize {
        if card.background.style == .image,
           let originalSize = card.background.originalImageSize {
            let aspectRatio = originalSize.width / originalSize.height
            if card.size.width / aspectRatio <= card.size.height {
                return CGSize(width: card.size.width, height: card.size.width / aspectRatio)
            } else {
                return CGSize(width: card.size.height * aspectRatio, height: card.size.height)
            }
        }
        return card.size
    }
    
    var body: some View {
        ZStack {
            // Main card content
            cardContent
            
            // Edit mode controls - only visible when editing
            if card.isEditing {
                editModeControls
            }
            
            // Lock indicator - show when card is locked
            if card.isLocked {
                VStack {
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 12))
                            .padding(4)
                            .background(Circle().fill(Color.black.opacity(0.6)))
                        Spacer()
                    }
                    Spacer()
                }
                .padding(8)
            }
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .scaleEffect(canvasScale)
        .position(adjustedPosition)
        .opacity(card.opacity)
        .allowsHitTesting(!card.isLocked)  // Make card transparent to touches when locked
        .gesture(cardDragGesture)
        .popover(isPresented: $showingColorPicker) {
            ColorPickerView(
                backgroundColor: $card.backgroundColor,
                showingColorPicker: $showingColorPicker
            )
        }
        .sheet(isPresented: $showBackgroundSettings) {
            NavigationView {
                CardBackgroundSettings(background: $card.background)
                    .navigationBarItems(trailing: Button("Done") {
                        showBackgroundSettings = false
                    })
            }
            .frame(width: 300, height: 500)
        }
    }
    
    private var cardContent: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 8)
                .fill(card.backgroundColor)
                .stroke(card.isEditing ? Color.blue : Color.clear, lineWidth: 2)
            
            // Background pattern/image
            if card.background.style != .none {
                CardBackgroundView(
                    background: card.background,
                    size: cardSize
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Drawing canvas - always present but only interactive when in edit mode
            PKCardCanvasView(
                drawing: $card.drawing,
                tool: tool,
                color: color,
                lineWidth: lineWidth,
                isEditing: card.isEditing,
                cardId: card.id
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .allowsHitTesting(card.isEditing)
        }
    }
    
    private var editModeControls: some View {
        ZStack {
            // Menu button
            VStack {
                HStack {
                    Spacer()
                    CardMenuButton(
                        showingColorPicker: $showingColorPicker,
                        showBackgroundSettings: $showBackgroundSettings,
                        backgroundColor: $card.backgroundColor,
                        background: $card.background,
                        onDelete: onDelete
                    )
                    .padding(8)
                }
                Spacer()
            }
            
            // Resize handles
            ResizeHandles(
                size: $card.size,
                originalImageSize: card.background.style == .image ? card.background.originalImageSize : nil
            )
        }
        .allowsHitTesting(true)
    }
    
    private var cardDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Only allow dragging when in edit mode and allowFingerDrag is true
                if card.isEditing && card.allowFingerDrag {
                    isDragging = true
                    dragOffset = value.translation
                }
            }
            .onEnded { value in
                if card.isEditing && card.allowFingerDrag && isDragging {
                    // Update card position
                    let newPosition = CGPoint(
                        x: card.position.x + (value.translation.width / canvasScale),
                        y: card.position.y + (value.translation.height / canvasScale)
                    )
                    card.position = newPosition
                    dragOffset = .zero
                    isDragging = false
                }
            }
    }
}

// MARK: - Supporting Views
struct CardMenuButton: View {
    @Binding var showingColorPicker: Bool
    @Binding var showBackgroundSettings: Bool
    @Binding var backgroundColor: Color
    @Binding var background: CardBackground
    let onDelete: () -> Void
    
    var body: some View {
        Menu {
            Button {
                showingColorPicker.toggle()
            } label: {
                Label("Change Color", systemImage: "paintpalette")
            }
            
            Button {
                showBackgroundSettings.toggle()
            } label: {
                Label("Background Settings", systemImage: "square.grid.2x2")
            }
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Card", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundColor(.white)
                .font(.system(size: 16))
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.blue.opacity(0.8)))
        }
    }
}

struct ResizeHandles: View {
    @Binding var size: CGSize
    var originalImageSize: CGSize?
    
    var body: some View {
        VStack {
            HStack {
                ResizeHandle(corner: .topLeft, size: $size, originalImageSize: originalImageSize)
                Spacer()
                ResizeHandle(corner: .topRight, size: $size, originalImageSize: originalImageSize)
            }
            Spacer()
            HStack {
                ResizeHandle(corner: .bottomLeft, size: $size, originalImageSize: originalImageSize)
                Spacer()
                ResizeHandle(corner: .bottomRight, size: $size, originalImageSize: originalImageSize)
            }
        }
    }
}

struct ResizeHandle: View {
    let corner: Corner
    @Binding var size: CGSize
    let originalImageSize: CGSize?
    
    var body: some View {
        Circle()
            .fill(Color.blue)
            .frame(width: 20, height: 20)
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        var newSize = corner.resize(size: size, by: value.translation)
                        
                        // Maintain aspect ratio if we have an image
                        if let originalSize = originalImageSize {
                            let aspectRatio = originalSize.width / originalSize.height
                            
                            // Determine which dimension to use as the constraint
                            if newSize.width / aspectRatio <= newSize.height {
                                newSize.height = newSize.width / aspectRatio
                            } else {
                                newSize.width = newSize.height * aspectRatio
                            }
                        }
                        
                        // Ensure minimum size
                        size = CGSize(
                            width: max(100, newSize.width),
                            height: max(100, newSize.height)
                        )
                    }
            )
    }
}

struct ColorPickerView: View {
    @Binding var backgroundColor: Color
    @Binding var showingColorPicker: Bool
    
    var body: some View {
        VStack {
            Text("Change Card Color")
                .font(.headline)
                .padding(.bottom, 10)
            ColorPicker("Select Card Color", selection: $backgroundColor, supportsOpacity: true)
                .padding()
            Button("Done") {
                showingColorPicker = false
            }
            .padding(.top, 10)
        }
        .padding()
        .frame(width: 300, height: 200)
    }
}

// MARK: - Supporting Types
enum Corner: CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight
    
    func resize(size: CGSize, by translation: CGSize) -> CGSize {
        switch self {
        case .topLeft:
            return CGSize(
                width: size.width - translation.width,
                height: size.height - translation.height
            )
        case .topRight:
            return CGSize(
                width: size.width + translation.width,
                height: size.height - translation.height
            )
        case .bottomLeft:
            return CGSize(
                width: size.width - translation.width,
                height: size.height + translation.height
            )
        case .bottomRight:
            return CGSize(
                width: size.width + translation.width,
                height: size.height + translation.height
            )
        }
    }
}
