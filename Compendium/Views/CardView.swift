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
    
    private var adjustedPosition: CGPoint {
        CGPoint(
            x: (card.position.x * canvasScale) - canvasOffset.x,
            y: (card.position.y * canvasScale) - canvasOffset.y
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
            // Use the simple direct touch handler with debug prints
            SimpleTouchCardView(
                card: $card,
                tool: tool,
                color: color,
                lineWidth: lineWidth,
                canvasOffset: $canvasOffset,
                canvasScale: $canvasScale,
                onDelete: onDelete
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Menu and editing controls - only visible in edit mode
            if card.isEditing {
                // Menu button
                VStack {
                    Spacer().frame(height: 8)
                    CardMenuButton(
                        showingColorPicker: $showingColorPicker,
                        showBackgroundSettings: $showBackgroundSettings,
                        backgroundColor: $card.backgroundColor,
                        background: $card.background,
                        onDelete: onDelete
                    )
                    Spacer()
                }
                .zIndex(100) // Ensure on top
                
                // Resize handles
                ResizeHandles(
                    size: $card.size,
                    originalImageSize: card.background.style == .image ? card.background.originalImageSize : nil
                )
                .zIndex(100) // Ensure on top
            }
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .scaleEffect(canvasScale)
        .position(adjustedPosition)
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
                .font(.system(size: 24))
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.blue.opacity(0.6)))
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
