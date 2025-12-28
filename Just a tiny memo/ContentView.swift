import SwiftUI

struct ContentView: View {
    // 1. Connect to the shared Source of Truth
    @EnvironmentObject var panelManager: PanelManager
    
    @State private var imageToCrop: NSImage?
    @State private var isImporting = false
    
    // MARK: - Logic
    
    private func saveImages(original: NSImage, cropped: NSImage) {
        Task {
            // 1. Optimistic UI Update (Instant)
            // We manually resize the cropped image for the menu bar state so the
            // in-memory version matches what the persistence service will create on disk.
            let menuBarHeight = NSStatusBar.system.thickness
            let targetHeight = max(18, menuBarHeight - 4)
            let smallIcon = cropped.resized(toHeight: targetHeight)
            
            panelManager.updateImage(newPanelImage: original, newMenuBarImage: smallIcon)
            
            // 2. Persist to Disk (Background)
            do {
                try await ImagePersistenceService.shared.save(original: original, menu: cropped)
                await ImagePersistenceService.shared.cleanup()
            } catch {
                print("Failed to save images: \(error)")
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack {
                ZStack {
                    ZStack {
                        // 3. Read directly from Manager
                        if let image = panelManager.panelImage {
                            Image(nsImage: image)
                                .resizable()
                                .interpolation(.high)
                                .aspectRatio(contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            EmptyView()
                        }
                    }
                    .padding(8)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 14).fill(Color(nsColor: .separatorColor))
                            
                            RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .underPageBackgroundColor)).padding(4)
                        }
                    )
                }
                .padding(60)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                HStack {
                    Spacer()
                    
                    VStack {
                        Button("Choose Image…") {
                            isImporting = true
                        }
                    }
                }
                .padding([.bottom, .trailing])
            }
            .background(content: {
                Rectangle()
                    .fill(
                        Color(nsColor: .underPageBackgroundColor).gradient
                    )
                    .rotationEffect(Angle(degrees: 180))
                    .opacity(0.2)
            })
            .border(Color(nsColor: .separatorColor), width: 1)
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.image],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        let accessing = url.startAccessingSecurityScopedResource()
                        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                        
                        if let image = NSImage(contentsOf: url) {
                            self.imageToCrop = image
                        }
                    }
                case .failure(let error):
                    print("File import failed: \(error.localizedDescription)")
                }
            }
            .navigationDestination(item: $imageToCrop) { image in
                CropImageView(
                    inputImage: image,
                    onSave: { original, cropped in
                        saveImages(original: original, cropped: cropped)
                        self.imageToCrop = nil
                    },
                    onCancel: {
                        self.imageToCrop = nil
                    }
                )
            }
            .frame(width: 553)
            // Removed .onAppear { loadSavedImage() }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(PanelManager())
}
