//
//  PanelManager.swift
//  Just a tiny memo
//
//  Created by Greco on 27/12/25.
//

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
        
        // Optional: If you want to ensure the file system is also synced for next launch
        // you would save here, or assume the caller saved it.
    }
    
    /// Alternatively, if your Settings only writes to disk and doesn't pass the image back:
    /// Call this to force a background reload.
    func reloadImages() {
        Task {
            await loadImages()
        }
    }

    // MARK: - Async Loading Logic
    
    private func loadImages() async {
        // Run heavy I/O on a background thread
        let (pImg, mImg) = await Task.detached(priority: .userInitiated) { () -> (NSImage?, NSImage?) in
            let p = ImagePersistenceService.shared.load(imageName: "original_image.png")
            let m = ImagePersistenceService.shared.load(imageName: "menubar_image.png")
            // Crucial: Force the image to decode now, not when drawn
            p?.precache()
            return (p, m)
        }.value
        
        // Update UI on MainActor
        self.panelImage = pImg
        self.menuBarImage = mImg
    }
}

// MARK: - Helper Extension

extension NSImage {
    /// Forces the image data to be read from disk into memory immediately.
    func precache() {
        // Drawing into a context forces the bitmap data to be decoded.
        // This prevents a "hiccup" the first time the panel is presented.
        _ = self.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
