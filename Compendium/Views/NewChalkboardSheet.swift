import SwiftUI
import PencilKit

struct NewChalkboardSheet: View {
    let store: ChalkboardStore
    @Binding var isPresented: Bool
    @Binding var chalkboardName: String
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Chalkboard Name", text: $chalkboardName)
                }
            }
            .navigationTitle("New Chalkboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if !chalkboardName.isEmpty {
                            store.createChalkboard(
                                name: chalkboardName,
                                drawing: PKDrawing(),
                                cards: []
                            )
                            isPresented = false
                            chalkboardName = ""
                        }
                    }
                    .disabled(chalkboardName.isEmpty)
                }
            }
        }
    }
}
