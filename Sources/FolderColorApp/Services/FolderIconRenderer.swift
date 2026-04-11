import AppKit
import Foundation

final class FolderIconRenderer {
    private let fallbackFolderIcon: NSImage = {
        if let image = NSImage(named: NSImage.folderName) {
            return image
        }
        let image = NSWorkspace.shared.icon(for: .folder)
        image.size = NSSize(width: 512, height: 512)
        return image
    }()

    func renderIcon(from customization: FolderCustomizationDraft, size: CGFloat = 512) -> NSImage {
        let targetSize = NSSize(width: size, height: size)
        let canvas = NSImage(size: targetSize)
        let rect = NSRect(origin: .zero, size: targetSize)

        let baseImage = resolveBaseImage(for: customization, size: targetSize)

        canvas.lockFocus()

        baseImage.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)

        if let tintColor = activeTintColor(for: customization) {
            tintColor.withAlphaComponent(0.42).setFill()
            rect.fill(using: .sourceAtop)
        }

        if customization.replacementMode == .systemPreset {
            drawSymbolBadge(for: customization.selectedPreset, in: rect)
        }

        canvas.unlockFocus()
        return canvas
    }

    func renderPresetPreview(for preset: SystemIconPreset, size: CGFloat = 128) -> NSImage {
        var previewDraft = FolderCustomizationDraft.default
        previewDraft.useTint = false
        previewDraft.replacementMode = .systemPreset
        previewDraft.selectedPreset = preset
        return renderIcon(from: previewDraft, size: size)
    }

    private func resolveBaseImage(for customization: FolderCustomizationDraft, size: NSSize) -> NSImage {
        switch customization.replacementMode {
        case .customFile:
            if let customIcon = customization.customIconImage {
                return customIcon.resized(to: size)
            }
            return fallbackFolderIcon.resized(to: size)

        case .none, .systemPreset:
            return fallbackFolderIcon.resized(to: size)
        }
    }

    private func activeTintColor(for customization: FolderCustomizationDraft) -> NSColor? {
        if customization.useTint {
            return customization.tintColor.nsColor
        }

        if customization.replacementMode == .systemPreset {
            return customization.selectedPreset.accentColor.nsColor
        }

        return nil
    }

    private func drawSymbolBadge(for preset: SystemIconPreset, in rect: NSRect) {
        let badgeDiameter = rect.width * 0.34
        let badgeRect = NSRect(
            x: rect.maxX - badgeDiameter - rect.width * 0.08,
            y: rect.minY + rect.width * 0.08,
            width: badgeDiameter,
            height: badgeDiameter
        )

        let badgePath = NSBezierPath(ovalIn: badgeRect)
        preset.accentColor.nsColor.withAlphaComponent(0.95).setFill()
        badgePath.fill()

        NSColor.white.withAlphaComponent(0.22).setStroke()
        badgePath.lineWidth = 2
        badgePath.stroke()

        guard
            let symbol = NSImage(systemSymbolName: preset.symbolName, accessibilityDescription: preset.title),
            let configured = symbol.withSymbolConfiguration(.init(pointSize: badgeDiameter * 0.42, weight: .bold))
        else {
            return
        }

        let symbolImage = configured.tintedSymbol(.white)
        let symbolRect = NSRect(
            x: badgeRect.midX - badgeDiameter * 0.22,
            y: badgeRect.midY - badgeDiameter * 0.22,
            width: badgeDiameter * 0.44,
            height: badgeDiameter * 0.44
        )

        symbolImage.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1)
    }
}
