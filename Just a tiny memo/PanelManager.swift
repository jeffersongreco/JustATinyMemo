import SwiftUI
import AppKit
import PanelKit

@MainActor
class PanelManager: NSObject, ObservableObject {
    @Published var menuBarImage: NSImage?
    @Published var panelImage: NSImage?
    
    private var panelController: PanelController<ImmersiveStyle>?

    override init() {
        super.init()

        let contentView = PanelContentView(manager: self)
        
        self.panelController = PanelController(
            style: ImmersiveStyle(),
            content: AnyView(contentView)
        )
        
        Task {
            await loadImages()
        }
    }
    
    @objc func menuBarIconClicked(_ sender: AnyObject?) {
        if panelController?.state.isOpen == true {
            panelController?.dismiss()
        } else {
            panelController?.present()
        }
    }
    
    func updateImage(newPanelImage: NSImage, newMenuBarImage: NSImage) {
        self.panelImage = newPanelImage
        self.menuBarImage = newMenuBarImage
    }
    
    func reloadImages() {
        Task {
            await loadImages()
        }
    }
    
    private func loadImages() async {
        let result = await ImagePersistenceService.shared.load()
        
        self.panelImage = result.original
        self.menuBarImage = result.menu
    }
}
