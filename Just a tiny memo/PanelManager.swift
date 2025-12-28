import SwiftUI
import AppKit
import PanelKit

@MainActor
class PanelManager: NSObject, ObservableObject {
    // MARK: Public State
    @Published var menuBarImage: NSImage?
    @Published var panelImage: NSImage?
    
    // MARK: Private
    private var panelController: PanelController<ImmersiveStyle>?

    override init() {
        super.init()

        let contentView = PanelContentView(manager: self)
        
        self.panelController = PanelController(
            style: ImmersiveStyle(),
            content: AnyView(contentView)
        )
        
        // Initial async load
        Task {
            await loadImages()
        }
    }

    // MARK: - Actions
    
    @objc func menuBarIconClicked(_ sender: AnyObject?) {
        // Pure UI logic. No file checks. Instant response.
        if panelController?.state.isOpen == true {
            panelController?.dismiss()
        } else {
            panelController?.present()
        }
    }
    
    /// Call this function from your Settings View immediately after saving a new image.
    /// This updates the live view without needing to read from disk again.
    func updateImage(newPanelImage: NSImage, newMenuBarImage: NSImage) {
        self.panelImage = newPanelImage
        self.menuBarImage = newMenuBarImage
    }
    
    /// Trigger a reload from disk if external changes occurred.
    func reloadImages() {
        Task {
            await loadImages()
        }
    }

    // MARK: - Async Loading Logic
    
    private func loadImages() async {
        // The Actor now handles the heavy lifting (IO, Decoding, Resizing)
        // in its own detached tasks, so we can simply await the result here.
        let (pImg, mImg) = await ImagePersistenceService.shared.load()
        
        // Update Published properties on MainActor
        self.panelImage = pImg
        self.menuBarImage = mImg
    }
}
