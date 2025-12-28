import SwiftUI

struct ContentView: View {
    @State private var currentImageOriginal: NSImage?
    @State private var currentImageCropped: NSImage?
    @State private var imageToCrop: NSImage?
    @State private var isImporting = false
    
    private func loadSavedImage() {
        if let savedOriginal = ImagePersistenceService.shared.load(
            imageName: "original_image.png"
        ) {
            self.currentImageOriginal = savedOriginal
        }
        
        if let savedCropped = ImagePersistenceService.shared.load(
            imageName: "cropped_image.png"
        ) {
            self.currentImageCropped = savedCropped
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                ZStack {
                    ZStack {
                        
                        // Wallpaper aqui
                        
                        if let image = currentImageOriginal {
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
                        Button("Chose Image…") {
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
                        if url.startAccessingSecurityScopedResource() {
                            defer { url.stopAccessingSecurityScopedResource() }
                            if let image = NSImage(contentsOf: url) {
                                self.imageToCrop = image
                            }
                        } else {
                            if let image = NSImage(contentsOf: url) {
                                self.imageToCrop = image
                            }
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
            .onAppear {
                loadSavedImage()
            }
        }
    }
    
    private func saveImages(original: NSImage, cropped: NSImage) {
        do {
            // Save original
            _ = try ImagePersistenceService.shared.save(
                image: original,
                withName: "original_image.png"
            )
            // Save cropped (high-res)
            _ = try ImagePersistenceService.shared.save(
                image: cropped,
                withName: "cropped_image.png"
            )
            
            // Resize and save menu bar image
            // Use system thickness minus a small padding (e.g. 4px total, 2px top/bottom) 
            // to ensure it fits nicely. Standard thickness is usually 22 or 24.
            let menuBarHeight = NSStatusBar.system.thickness
            let targetHeight = max(18, menuBarHeight - 4) 
            let resizedImage = cropped.resized(toHeight: targetHeight)
            // Set template to true so it adapts to light/dark mode if it's a monochrome icon, 
            // though for user photos we might want to keep it as is. 
            // User didn't specify, so we keep original colors.
            
            _ = try ImagePersistenceService.shared.save(
                image: resizedImage,
                withName: "menubar_image.png"
            )
            
            // Cleanup old files
            ImagePersistenceService.shared.cleanup()
            
            // Update current image state
            self.currentImageOriginal = original
            self.currentImageCropped = cropped
        } catch {
            print("Failed to save images: \(error)")
        }
    }
}

#Preview {
    ContentView()
}
