import SwiftUI
import PencilKit

extension Card: Hashable {
    static func == (lhs: Card, rhs: Card) -> Bool {
        // Include all properties that should trigger a view update
        lhs.id == rhs.id &&
        lhs.position == rhs.position &&
        lhs.size == rhs.size &&
        lhs.backgroundColor == rhs.backgroundColor &&
        lhs.opacity == rhs.opacity &&
        lhs.isEditing == rhs.isEditing &&
        lhs.background == rhs.background &&
        lhs.allowFingerDrag == rhs.allowFingerDrag  // Add this line
        // Note: We intentionally exclude drawing from equality check
        // as it would be too expensive to compare and isn't needed
        // for view updates
    }
    
    func hash(into hasher: inout Hasher) {
        // We still only use id for hash since that's what uniquely identifies the card
        hasher.combine(id)
    }
}

struct Card: Identifiable, Equatable, Codable {
    let id: UUID
    var drawing: PKDrawing
    var position: CGPoint
    var size: CGSize
    var backgroundColor: Color
    var opacity: Double
    var isEditing: Bool
    var background: CardBackground
    var allowFingerDrag: Bool = true  // Add this property
    
    init(
        id: UUID = UUID(),
        position: CGPoint = .zero,
        size: CGSize = CGSize(width: 300, height: 200),
        backgroundColor: Color = .yellow,
        opacity: Double = 1.0,
        isEditing: Bool = false,
        background: CardBackground = .default,
        allowFingerDrag: Bool = true  // Add this parameter
    ) {
        self.id = id
        self.drawing = PKDrawing()
        self.position = position
        self.size = size
        self.backgroundColor = backgroundColor
        self.opacity = opacity
        self.isEditing = isEditing
        self.background = background
        self.allowFingerDrag = allowFingerDrag
    }
    
    // Update Codable implementation...
    enum CodingKeys: String, CodingKey {
        case id, drawing, position, size, backgroundColor, opacity, isEditing, background, allowFingerDrag
    }
    
    // Update encode method
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(drawing.dataRepresentation(), forKey: .drawing)
        try container.encode(position, forKey: .position)
        try container.encode(size, forKey: .size)
        try container.encode(backgroundColor, forKey: .backgroundColor)
        try container.encode(opacity, forKey: .opacity)
        try container.encode(isEditing, forKey: .isEditing)
        try container.encode(background, forKey: .background)
        try container.encode(allowFingerDrag, forKey: .allowFingerDrag)
    }
    
    // Update init(from:) method
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        let drawingData = try container.decode(Data.self, forKey: .drawing)
        self.drawing = try PKDrawing(data: drawingData)
        self.position = try container.decode(CGPoint.self, forKey: .position)
        self.size = try container.decode(CGSize.self, forKey: .size)
        self.backgroundColor = try container.decode(Color.self, forKey: .backgroundColor)
        self.opacity = try container.decode(Double.self, forKey: .opacity)
        self.isEditing = try container.decode(Bool.self, forKey: .isEditing)
        self.background = try container.decode(CardBackground.self, forKey: .background)
        // Decode allowFingerDrag if it exists, otherwise default to true
        self.allowFingerDrag = try container.decodeIfPresent(Bool.self, forKey: .allowFingerDrag) ?? true
    }
}

// MARK: - Convenience Initializers and Methods
extension Card {
    // Create a copy of a card
    func copy() -> Card {
        Card(
            id: UUID(), // New ID for the copy
            position: CGPoint(x: position.x + 20, y: position.y + 20), // Offset slightly
            size: size,
            backgroundColor: backgroundColor,
            opacity: opacity,
            isEditing: false,
            background: background,
            allowFingerDrag: allowFingerDrag
        )
    }
    
    // Reset the card to default state
    mutating func reset() {
        drawing = PKDrawing()
        backgroundColor = .yellow
        opacity = 1.0
        isEditing = false
        allowFingerDrag = true
    }
}

// Extension to make Color codable
extension Color: Codable {
    struct ColorComponents: Codable {
        let red: Double
        let green: Double
        let blue: Double
        let opacity: Double
    }
    
    enum CodingKeys: String, CodingKey {
        case components
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var opacity: CGFloat = 0
        
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &opacity)
        
        let components = ColorComponents(red: Double(red),
                                         green: Double(green),
                                         blue: Double(blue),
                                         opacity: Double(opacity))
        try container.encode(components, forKey: .components)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let components = try container.decode(ColorComponents.self, forKey: .components)
        
        self.init(.sRGB,
                  red: components.red,
                  green: components.green,
                  blue: components.blue,
                  opacity: components.opacity)
    }
}
