import SwiftUI
import PencilKit

struct NewCreationSheet: View {
    let store: ChalkboardStore
    @Binding var isPresented: Bool
    @Binding var chalkboardName: String
    @State private var selectedType: CreationType = .chalkboard
    @State private var selectedCard: Card?
    
    enum CreationType {
        case chalkboard
        case card
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Type", selection: $selectedType) {
                        Text("Chalkboard").tag(CreationType.chalkboard)
                        Text("Card").tag(CreationType.card)
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 8)
                }
                
                if selectedType == .chalkboard {
                    Section {
                        TextField("Chalkboard Name", text: $chalkboardName)
                    }
                }
                
                // Preview section for card creation
                if selectedType == .card {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Preview")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(red: 1, green: 0.2157, blue: 0.3725, opacity: 0.67))
                                .frame(height: 120)
                        }
                    }
                }
            }
            .navigationTitle(selectedType == .chalkboard ? "New Chalkboard" : "New Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        if selectedType == .chalkboard {
                            if !chalkboardName.isEmpty {
                                store.createChalkboard(
                                    name: chalkboardName,
                                    drawing: PKDrawing(),
                                    cards: []
                                )
                                chalkboardName = ""
                            }
                        } else {
                            let newCard = store.createUnassignedCard()
                            selectedCard = newCard
                        }
                        isPresented = false
                    }
                    .disabled(selectedType == .chalkboard && chalkboardName.isEmpty)
                }
            }
        }
        .sheet(item: $selectedCard) { card in
            NavigationStack {  // Changed from NavigationView
                UnassignedCardView(card: card)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                selectedCard = nil
                            }
                        }
                    }
            }
        }
    }
}

#Preview {
    NewCreationSheet(
        store: ChalkboardStore(),
        isPresented: .constant(true),
        chalkboardName: .constant("")
    )
}
