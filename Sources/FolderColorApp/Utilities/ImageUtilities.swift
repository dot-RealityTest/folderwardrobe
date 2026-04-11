import AppKit
import Foundation

extension NSImage {
    func resized(to targetSize: NSSize) -> NSImage {
        let image = NSImage(size: targetSize)
        image.lockFocus()
        draw(in: NSRect(origin: .zero, size: targetSize), from: .zero, operation: .copy, fraction: 1)
        image.unlockFocus()
        image.size = targetSize
        return image
    }

    func pngData(maxDimension: CGFloat? = nil) -> Data? {
        let sourceImage: NSImage
        if let maxDimension {
            let longestEdge = max(size.width, size.height)
            if longestEdge > maxDimension, longestEdge > 0 {
                let scale = maxDimension / longestEdge
                let targetSize = NSSize(width: size.width * scale, height: size.height * scale)
                sourceImage = resized(to: targetSize)
            } else {
                sourceImage = self
            }
        } else {
            sourceImage = self
        }

        guard
            let tiff = sourceImage.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff)
        else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }

    func applyingTint(_ color: NSColor, alpha: CGFloat) -> NSImage {
        let output = NSImage(size: size)
        output.lockFocus()
        let rect = NSRect(origin: .zero, size: size)
        draw(in: rect)
        color.withAlphaComponent(alpha).setFill()
        rect.fill(using: .sourceAtop)
        output.unlockFocus()
        return output
    }

    func tintedSymbol(_ color: NSColor) -> NSImage {
        let output = NSImage(size: size)
        output.lockFocus()
        color.setFill()
        let rect = NSRect(origin: .zero, size: size)
        rect.fill()
        draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1)
        output.unlockFocus()
        return output
    }
}
