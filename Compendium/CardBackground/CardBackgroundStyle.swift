import SwiftUI

enum CardBackgroundStyle: String, Codable {
    case none
    case grid
    case lined
    case image
}

struct CardMargins: Codable, Equatable {
    var left: Margin
    var right: Margin
    var top: Margin
    var bottom: Margin
    
    struct Margin: Codable, Equatable {
        var isEnabled: Bool
        var percentage: Double  // 0-100
        
        static let `default` = Margin(isEnabled: false, percentage: 20)  // 20% default
    }
    
    static let `default` = CardMargins(
        left: .default,
        right: .default,
        top: .default,
        bottom: .default
    )
}

struct CardBackground: Codable, Equatable {
    var style: CardBackgroundStyle
    var lineColor: Color
    var lineWidth: CGFloat
    var spacing: CGFloat
    var margins: CardMargins
    var imageData: Data?
    var originalImageSize: CGSize?
    var imageOpacity: Double
    
    static let `default` = CardBackground(
        style: .none,
        lineColor: .white,
        lineWidth: 1,
        spacing: 20,
        margins: .default,
        imageData: nil,
        originalImageSize: nil,
        imageOpacity: 1.0
    )
}
