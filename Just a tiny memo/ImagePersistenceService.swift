import AppKit
import OSLog

actor ImagePersistenceService {
    static let shared = ImagePersistenceService()
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "JustATinyMemo", category: "Persistence")
    
    private var appSupportDirectory: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    }
    
    private func ensureDirectoryExists() throws -> URL {
        guard let appSupport = appSupportDirectory else {
            throw NSError(domain: "ImagePersistenceService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Application Support directory not found"])
        }
        
        let appDirectory = appSupport.appendingPathComponent("JustATinyMemo", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: appDirectory.path) {
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        
        return appDirectory
    }
        
    func load() async -> (original: NSImage?, menu: NSImage?) {
        guard let directory = try? ensureDirectoryExists() else { return (nil, nil) }
        
        let originalURL = directory.appendingPathComponent("original_image.png")
        let menuURL = directory.appendingPathComponent("menubar_image.png")
        
        struct ImageTransport: @unchecked Sendable {
            let original: NSImage?
            let menu: NSImage?
        }
        
        let result = await Task.detached {
            let original = NSImage(contentsOf: originalURL)?.eagerlyDecoded()
            let menu = NSImage(contentsOf: menuURL)?.eagerlyDecoded()
            return ImageTransport(original: original, menu: menu)
        }.value
        
        return (result.original, result.menu)
    }
        
    func save(original: NSImage, menu: NSImage) async throws {
        let directory = try ensureDirectoryExists()
        
        let menuBarHeight = await MainActor.run { NSStatusBar.system.thickness }
        let targetHeight = max(18, menuBarHeight - 4)
        
        try await Task.detached { [weak self] in
            guard let self else { return }
            
            let originalURL = directory.appendingPathComponent("original_image.png")
            try self.write(image: original, to: originalURL)
            
            let resizedMenu = menu.resized(toHeight: targetHeight).eagerlyDecoded()
            let menuURL = directory.appendingPathComponent("menubar_image.png")
            try self.write(image: resizedMenu, to: menuURL)
            
        }.value
    }
        
    private nonisolated func write(image: NSImage, to url: URL) throws {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "ImagePersistenceService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to PNG"])
        }
        
        try pngData.write(to: url)
    }
    
    func cleanup() async {
        guard let directory = try? ensureDirectoryExists() else { return }
        
        let allowedFiles = Set(["original_image.png", "menubar_image.png"])
        
        await Task.detached {
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                
                for fileURL in fileURLs {
                    if !allowedFiles.contains(fileURL.lastPathComponent) {
                        try FileManager.default.removeItem(at: fileURL)
                    }
                }
            } catch {
                self.logger.error("Failed to cleanup directory: \(error.localizedDescription, privacy: .public)")
            }
        }.value
    }
    
    func fileURL(for imageName: String) -> URL? {
        guard let directory = try? ensureDirectoryExists() else { return nil }
        return directory.appendingPathComponent(imageName)
    }
}

extension NSImage {
    
    func eagerlyDecoded() -> NSImage {
        let imageSize = self.size
        
        let scale = AppKit.NSScreen.main?.backingScaleFactor ?? 2.0
        
        let pixelWidth = Int(imageSize.width * scale)
        let pixelHeight = Int(imageSize.height * scale)
        
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return self
        }
        
        rep.size = imageSize
        
        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current = context
        
        self.draw(in: NSRect(origin: .zero, size: imageSize),
                  from: .zero,
                  operation: .copy,
                  fraction: 1.0)
        
        NSGraphicsContext.restoreGraphicsState()
        
        if let cgImage = rep.cgImage {
            return NSImage(cgImage: cgImage, size: imageSize)
        }
        
        return self
    }
    
    func resized(toHeight newHeight: CGFloat) -> NSImage {
        guard size.height > 0 else { return self }
        
        let aspectRatio = size.width / size.height
        let newWidth = newHeight * aspectRatio
        let newSize = NSSize(width: newWidth, height: newHeight)
        
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(newWidth),
            pixelsHigh: Int(newHeight),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return self }
        
        rep.size = newSize
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        self.draw(in: NSRect(origin: .zero, size: newSize),
                  from: NSRect(origin: .zero, size: self.size),
                  operation: .copy,
                  fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()
        
        return NSImage(cgImage: rep.cgImage!, size: newSize)
    }
}
