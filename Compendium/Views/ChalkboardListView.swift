import SwiftUI
import PencilKit

struct ChalkboardListView: View {
    @EnvironmentObject var store: ChalkboardStore
    @State private var showingNewChalkboardSheet = false
    @State private var showingNewCardSheet = false
    @State private var newChalkboardName = ""
    @State private var currentContent: SidePanelContent = .chalkboards
    @State private var selectedChalkboardId: UUID?
    @State private var selectedUnassignedCard: Card?
    @State private var chalkboardViewRef: ChalkboardView?
    @State private var previousChalkboardId: UUID?
    
    // Add environment value to detect device type
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var selectedChalkboard: Chalkboard? {
        guard let id = selectedChalkboardId else { return nil }
        return store.chalkboards.first { $0.id == id }
    }
    
    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // Use NavigationSplitView for iPad/desktop
                NavigationSplitView {
                    sidebarContent
                } detail: {
                    detailContent
                }
            } else {
                // Use NavigationStack for mobile
                NavigationStack {
                    sidebarContent
                        .navigationDestination(for: UUID.self) { id in
                            if let chalkboard = store.chalkboards.first(where: { $0.id == id }) {
                                ChalkboardView(chalkboard: chalkboard)
                                    .navigationBarBackButtonHidden(false)
                                    .id(chalkboard.id)
                            }
                        }
                        .navigationDestination(for: Card.self) { card in
                            UnassignedCardView(card: card)
                        }
                }
            }
        }
        .sheet(isPresented: $showingNewChalkboardSheet) {
            CreateNewSheet(
                store: store,
                isPresented: $showingNewChalkboardSheet,
                chalkboardName: $newChalkboardName
            )
        }
        .preferredColorScheme(.dark)
    }
    
    private var sidebarContent: some View {
        HStack(spacing: 0) {
            // Side Navigation
            VStack(spacing: 4) {
                NavigationButton(
                    icon: "square.grid.2x2",
                    isSelected: currentContent == .chalkboards,
                    action: { 
                        withAnimation { currentContent = .chalkboards }
                    }
                )
                
                NavigationButton(
                    icon: "rectangle.stack",
                    isSelected: currentContent == .cards,
                    action: {
                        withAnimation { currentContent = .cards }
                    }
                )
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(Color.black)
            
            // Main Content Area
            Group {
                if currentContent == .chalkboards {
                    ChalkboardsList(
                        selectedChalkboardId: $selectedChalkboardId,
                        showingNewChalkboardSheet: $showingNewChalkboardSheet,
                        onDeleteChalkboard: { id in
                            store.deleteChalkboard(id)
                            if selectedChalkboardId == id {
                                selectedChalkboardId = nil
                            }
                        }
                    )
                } else {
                    UnassignedCardsList(
                        selectedCard: $selectedUnassignedCard,
                        newChalkboardName: $newChalkboardName,
                        selectedChalkboardId: selectedChalkboardId,
                        canvasOffset: selectedChalkboard?.canvasOffset ?? .zero,
                        canvasScale: selectedChalkboard?.zoomScale ?? 1.0
                    )
                }
            }
        }
        .background(Color.black)
    }
    
    private var detailContent: some View {
        Group {
            if let selectedCard = selectedUnassignedCard {
                UnassignedCardView(card: selectedCard)
            } else if let selectedId = selectedChalkboardId,
                      let chalkboard = store.chalkboards.first(where: { $0.id == selectedId }) {
                ChalkboardView(chalkboard: chalkboard)
                    .id(chalkboard.id)
                    .environment(\.colorScheme, .light)
            } else {
                Text("Select a chalkboard or card")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - UnassignedCardsList
struct UnassignedCardsList: View {
    @EnvironmentObject var store: ChalkboardStore
    @Binding var selectedCard: Card?
    @Binding var newChalkboardName: String
    let selectedChalkboardId: UUID?
    let canvasOffset: CGPoint
    let canvasScale: CGFloat
    @State private var showingNewCardSheet = false
    @State private var showingNewChalkboardSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Unassigned Cards")
                    .font(.headline)
                    .foregroundColor(.white)
                
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.black)
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(store.unassignedCards) { card in
                        UnassignedCardRow(
                            card: card,
                            isSelected: selectedCard?.id == card.id,
                            onTap: { selectedCard = card },
                            onAddToCanvas: { addCardToCanvas(card) }
                        )
                        .contextMenu {
                            if selectedChalkboardId != nil {
                                Button {
                                    addCardToCanvas(card)
                                } label: {
                                    Label("Add to Canvas", systemImage: "plus.square.on.square")
                                }
                            }
                            
                            Button(role: .destructive) {
                                store.deleteUnassignedCard(card.id)
                            } label: {
                                Label("Delete Card", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .sheet(isPresented: $showingNewChalkboardSheet) {
                CreateNewSheet(
                    store: store,
                    isPresented: $showingNewChalkboardSheet,
                    chalkboardName: $newChalkboardName
                )
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewChalkboardSheet = true  // This will now work
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewCardSheet) {
            NavigationStack {
                let card = store.createUnassignedCard()
                UnassignedCardView(card: card)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showingNewCardSheet = false
                            }
                        }
                    }
            }
        }
        .navigationDestination(item: $selectedCard) { card in
            UnassignedCardView(card: card)
        }
        .background(Color.black)
    }
    
    private func addCardToCanvas(_ card: Card) {
        if let chalkboardId = selectedChalkboardId {
            store.addCardToChalkboard(card, chalkboardId: chalkboardId, canvasOffset: canvasOffset, canvasScale: canvasScale)
        }
    }}

// MARK: - UnassignedCardRow
struct UnassignedCardRow: View {
    let card: Card
    let isSelected: Bool
    let onTap: () -> Void
    let onAddToCanvas: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Preview
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(card.backgroundColor)
                        .opacity(card.opacity)
                    
                    if card.background.style != .none {
                        CardBackgroundView(
                            background: card.background,
                            size: CGSize(width: 200, height: 120)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    CardDrawingPreview(drawing: card.drawing)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .frame(height: 120)
                .shadow(radius: 2)
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Size: \(Int(card.size.width))×\(Int(card.size.height))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color(red: 1, green: 0.2157, blue: 0.3725) : Color(UIColor.secondarySystemBackground))
            )
        }
    }
}

// MARK: - CreateNewSheet
struct CreateNewSheet: View {
    let store: ChalkboardStore
    @Binding var isPresented: Bool
    @Binding var chalkboardName: String
    @State private var selectedType: CreateType = .chalkboard
    
    enum CreateType {
        case chalkboard
        case card
    }
    
    var body: some View {
        NavigationView {
            Form {
                Picker("Type", selection: $selectedType) {
                    Text("Chalkboard").tag(CreateType.chalkboard)
                    Text("Card").tag(CreateType.card)
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 8)
                
                if selectedType == .chalkboard {
                    Section {
                        TextField("Chalkboard Name", text: $chalkboardName)
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
                            _ = store.createUnassignedCard()
                        }
                        isPresented = false
                    }
                    .disabled(selectedType == .chalkboard && chalkboardName.isEmpty)
                }
            }
        }
    }
}

// MARK: - NavigationButton
struct NavigationButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    var customColor: Color? = nil
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(getForegroundColor())
                .frame(width: 44, height: 44)
                .background(isSelected ? Color.white.opacity(0.2) : Color.clear)
                .cornerRadius(8)
        }
    }
    
    private func getForegroundColor() -> Color {
        if let customColor = customColor {
            return customColor
        }
        return isSelected ? .white : .gray
    }
}

struct ChalkboardsList: View {
    @EnvironmentObject var store: ChalkboardStore
    @Binding var selectedChalkboardId: UUID?
    @Binding var showingNewChalkboardSheet: Bool
    let onDeleteChalkboard: (UUID) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Chalkboards")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }
            .background(Color.black)
            
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(store.chalkboards) { chalkboard in
                        ChalkboardRow(
                            chalkboard: chalkboard,
                            isSelected: selectedChalkboardId == chalkboard.id,
                            onDelete: {
                                onDeleteChalkboard(chalkboard.id)
                            }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedChalkboardId = chalkboard.id
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewChalkboardSheet = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .background(Color.black)
        }
        .background(Color.black)
    }
}

// MARK: - ChalkboardRow
struct ChalkboardRow: View {
    let chalkboard: Chalkboard
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false
    let isSelected: Bool
    let onDelete: () -> Void
    
    private let selectedColor = Color(red: 1, green: 0.2157, blue: 0.3725)
    private let hoverColor = Color.gray.opacity(0.2)
    private let previewHeight: CGFloat = 120
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Preview Image
            if let previewImage = chalkboard.previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: previewHeight)
                    .clipped()
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: previewHeight)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(chalkboard.name)
                    .foregroundColor(isSelected ? .black : .white)
                Text("Last edited: \(chalkboard.lastEditDate.formatted())")
                    .font(.caption)
                    .foregroundStyle(isSelected ? .black.opacity(0.8) : .secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isSelected ? selectedColor :
                        isHovered ? hoverColor : Color.clear
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Chalkboard", systemImage: "trash")
            }
        }
    }
}

#Preview {
    ChalkboardListView()
        .environmentObject(ChalkboardStore())
}
