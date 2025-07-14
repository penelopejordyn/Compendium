import SwiftUI

@main
struct MyApp: App {
    @StateObject private var store = ChalkboardStore()
    var body: some Scene {
        WindowGroup {
            ChalkboardListView()
                .environmentObject(store)
        }
        
    }
}
