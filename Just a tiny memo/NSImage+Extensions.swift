import AppKit

extension NSImage {
    func resized(toHeight newHeight: CGFloat) -> NSImage {
        let aspectRatio = size.width / size.height
        let newWidth = newHeight * aspectRatio
        let newSize = NSSize(width: newWidth, height: newHeight)
        
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: newSize),
                  from: NSRect(origin: .zero, size: self.size),
                  operation: .copy,
                  fraction: 1.0)
        newImage.unlockFocus()
        
        return newImage
    }
}
