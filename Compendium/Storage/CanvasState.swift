import SwiftUI

import SwiftUI

struct CanvasState: Equatable {
    var offset: CGPoint
    var scale: CGFloat
    
    static let `default` = CanvasState(offset: .zero, scale: 1.0)
}

struct CanvasStatePreferenceKey: PreferenceKey {
    static var defaultValue = CanvasState.default
    
    static func reduce(value: inout CanvasState, nextValue: () -> CanvasState) {
        value = nextValue()
    }
}

extension View {
    func onCanvasStateChange(_ action: @escaping (CanvasState) -> Void) -> some View {
        self.onPreferenceChange(CanvasStatePreferenceKey.self, perform: action)
    }
}

struct CanvasStateModifier: ViewModifier {
    let state: CanvasState
    
    func body(content: Content) -> some View {
        content.preference(key: CanvasStatePreferenceKey.self, value: state)
    }
}

