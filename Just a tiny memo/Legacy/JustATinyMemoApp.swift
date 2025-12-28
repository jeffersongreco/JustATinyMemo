import AppKit
import PanelKit
import MenuBarExtraAccess
import SwiftUI

// MARK: - App Entry Point

@main
struct JustATinyMemoApp: App {
    @StateObject private var panelManager = PanelManager()
    @State private var isMenuExtraPresented: Bool = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(panelManager)
        }

        MenuBarExtra {
            EmptyView()
        } label: {
            if let image = panelManager.menuBarImage {
                Image(nsImage: image)
            } else {
                Image(systemName: "photo")
            }
        }
        .menuBarExtraAccess(isPresented: $isMenuExtraPresented) { statusItem in
            setupStatusItem(statusItem)
        }
    }
    
    private func setupStatusItem(_ statusItem: NSStatusItem) {
        statusItem.menu = nil
        if let button = statusItem.button {
            button.target = panelManager
            button.action = #selector(PanelManager.menuBarIconClicked(_:))
            button.sendAction(on: [.leftMouseDown])
        }
    }
}

// MARK: - Reactive View

struct ReactiveMemoView: View {
    @ObservedObject var manager: PanelManager
    
    var body: some View {
        if let image = manager.panelImage {
            // Your custom content view
            PanelContentView(image: image)
                // Ensure the frame updates if the image aspect ratio changes
                .id(image)
        } else {
            // Optional: A loading state or placeholder
            Color.clear.frame(width: 200, height: 200)
        }
    }
}
