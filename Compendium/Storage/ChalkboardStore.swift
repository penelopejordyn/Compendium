import SwiftUI
import PencilKit

class ChalkboardStore: ObservableObject {
    @Published private(set) var chalkboards: [Chalkboard] = []
    @Published private(set) var unassignedCards: [Card] = []
    
    private let saveKey = "savedChalkboards"
    private let unassignedCardsKey = "unassignedCards"
    
    init() {
        loadChalkboards()
        loadUnassignedCards()
    }
    
    func createChalkboard(name: String, drawing: PKDrawing, cards: [Card]) {
        let newChalkboard = Chalkboard(name: name, drawing: drawing, cards: cards)
        chalkboards.append(newChalkboard)
        saveChalkboards()
    }
    
    func createUnassignedCard() -> Card {
        let newCard = Card(
            id: UUID(),
            position: .zero,
            size: CGSize(width: 300, height: 200),
            backgroundColor: Color(red: 1, green: 0.2157, blue: 0.3725, opacity: 0.67),
            opacity: 1.0,
            isEditing: false,
            background: .default
        )
        unassignedCards.append(newCard)
        saveUnassignedCards()
        return newCard
    }
    
    func updateUnassignedCard(_ card: Card) {
        if let index = unassignedCards.firstIndex(where: { $0.id == card.id }) {
            unassignedCards[index] = card
            saveUnassignedCards()
        }
    }
    
    func deleteUnassignedCard(_ id: UUID) {
        unassignedCards.removeAll { $0.id == id }
        saveUnassignedCards()
    }
    
    func addCardToChalkboard(_ card: Card, chalkboardId: UUID, canvasOffset: CGPoint, canvasScale: CGFloat) {
        if let index = chalkboards.firstIndex(where: { $0.id == chalkboardId }) {
            // Create a complete new copy of the chalkboard
            var updatedChalkboard = chalkboards[index]
            
            let screenCenter = CGPoint(
                x: UIScreen.main.bounds.width / 2,
                y: UIScreen.main.bounds.height / 2
            )
            
            let canvasPosition = CGPoint(
                x: (screenCenter.x + canvasOffset.x) / canvasScale,
                y: (screenCenter.y + canvasOffset.y) / canvasScale
            )
            
            // Create a new card with all the original card's properties
            var newCard = Card(
                id: UUID(),  // New ID
                position: canvasPosition,
                size: card.size,
                backgroundColor: card.backgroundColor,
                opacity: card.opacity,
                isEditing: false,
                background: card.background
            )
            
            // Copy the drawing data
            newCard.drawing = card.drawing
            
            // Add to chalkboard's cards
            updatedChalkboard.cards.append(newCard)
            
            // Force a publish event by modifying the entire array
            var newChalkboards = self.chalkboards
            newChalkboards[index] = updatedChalkboard
            self.chalkboards = newChalkboards
            
            // Remove from unassigned cards
            unassignedCards.removeAll { $0.id == card.id }
            
            saveChalkboards()
            saveUnassignedCards()
        }
    }
    
    func updateChalkboard(_ chalkboard: Chalkboard) {
        if let index = chalkboards.firstIndex(where: { $0.id == chalkboard.id }) {
            // Ensure we're not overwriting the preview if it wasn't included
            var updatedChalkboard = chalkboard
            if updatedChalkboard.previewImageData == nil {
                updatedChalkboard.previewImageData = chalkboards[index].previewImageData
            }
            chalkboards[index] = updatedChalkboard
            saveChalkboards()
        }
    }
    
    func deleteChalkboard(_ id: UUID) {
        chalkboards.removeAll { $0.id == id }
        saveChalkboards()
    }
    
    private func saveChalkboards() {
        if let encoded = try? JSONEncoder().encode(chalkboards) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadChalkboards() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Chalkboard].self, from: data) {
            chalkboards = decoded
        }
    }
    
    private func saveUnassignedCards() {
        if let encoded = try? JSONEncoder().encode(unassignedCards) {
            UserDefaults.standard.set(encoded, forKey: unassignedCardsKey)
        }
    }
    
    private func loadUnassignedCards() {
        if let data = UserDefaults.standard.data(forKey: unassignedCardsKey),
           let decoded = try? JSONDecoder().decode([Card].self, from: data) {
            unassignedCards = decoded
        }
    }
}
