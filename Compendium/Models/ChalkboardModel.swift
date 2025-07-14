import SwiftUI
import PencilKit

struct Chalkboard: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var drawingData: Data
    var cards: [Card]
    var lastEditDate: Date
    var canvasOffset: CGPoint
    var zoomScale: CGFloat
    var previewImageData: Data?  // New property for storing preview
    
    init(id: UUID = UUID(), 
         name: String, 
         drawing: PKDrawing, 
         cards: [Card],
         canvasOffset: CGPoint = .zero,
         zoomScale: CGFloat = 1.0,
         previewImageData: Data? = nil) {
        self.id = id
        self.name = name
        self.drawingData = drawing.dataRepresentation()
        self.cards = cards
        self.lastEditDate = Date()
        self.canvasOffset = canvasOffset
        self.zoomScale = zoomScale
        self.previewImageData = previewImageData
    }
    
    var drawing: PKDrawing {
        get {
            // Try to decompress, fallback to original if fails
            PKDrawing.drawing(fromCompressedData: drawingData) ?? 
            (try? PKDrawing(data: drawingData)) ?? 
            PKDrawing()
        }
        
        set {
            // Always store compressed
            drawingData = newValue.compressedDataRepresentation() ?? 
            newValue.dataRepresentation()
        }
    }
    
    var previewImage: UIImage? {
        guard let data = previewImageData else { return nil }
        return UIImage(data: data)
    }
}
