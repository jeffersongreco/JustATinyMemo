import SwiftUI
import AppKit
import FloatingPanel

struct PanelContentView: View {
    @ObservedObject var manager: PanelManager
    
    var body: some View {
        Group {
            if let image = manager.panelImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(image)
            }
        }
        .padding(80)
    }
}
