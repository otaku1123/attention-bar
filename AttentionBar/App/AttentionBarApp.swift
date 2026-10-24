import SwiftUI

@main
struct AttentionBarApp: App {
    @StateObject private var store = AttentionStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(store: store)
        } label: {
            Text(store.menuBarTitle)
        }
        .menuBarExtraStyle(.window)
    }
}
