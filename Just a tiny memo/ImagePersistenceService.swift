import Cocoa

class ImagePersistenceService {
    static let shared = ImagePersistenceService()
    
    private init() {}
    
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
    
    func save(image: NSImage, withName name: String) throws -> URL {
        let directory = try ensureDirectoryExists()
        let fileURL = directory.appendingPathComponent(name)
        
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "ImagePersistenceService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to PNG"])
        }
        
        try pngData.write(to: fileURL)
        return fileURL
    }
    
    func load(imageName: String) -> NSImage? {
        guard let directory = try? ensureDirectoryExists() else { return nil }
        let fileURL = directory.appendingPathComponent(imageName)
        return NSImage(contentsOf: fileURL)
    }
    
    func fileURL(for imageName: String) -> URL? {
        guard let directory = try? ensureDirectoryExists() else { return nil }
        return directory.appendingPathComponent(imageName)
    }
    
    func cleanup() {
        guard let directory = try? ensureDirectoryExists() else { return }
        
        let allowedFiles = Set(["original_image.png", "cropped_image.png", "menubar_image.png"])
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            
            for fileURL in fileURLs {
                if !allowedFiles.contains(fileURL.lastPathComponent) {
                    try FileManager.default.removeItem(at: fileURL)
                    print("Cleaned up file: \(fileURL.lastPathComponent)")
                }
            }
        } catch {
            print("Failed to cleanup directory: \(error)")
        }
    }
}
