import AppKit
import Foundation
import SwiftUI

struct FolderTarget: Identifiable, Hashable {
    let id: UUID
    let url: URL

    init(url: URL) {
        self.id = UUID()
        self.url = url
    }

    var displayName: String {
        url.lastPathComponent
    }

    var standardizedPath: String {
        url.standardizedFileURL.path
    }
}

enum OverlayMode: String, CaseIterable, Codable, Identifiable {
    case overlay
    case background

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overlay: return "Overlay"
        case .background: return "Background"
        }
    }
}

enum ReplacementMode: String, Codable, Identifiable, CaseIterable {
    case none
    case customFile
    case systemPreset

    // Keep legacy case decodable, but hide it from the UI.
    static var allCases: [ReplacementMode] { [.none, .customFile] }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "None"
        case .systemPreset: return "System"
        case .customFile: return "Custom"
        }
    }
}

enum SystemIconPreset: String, CaseIterable, Codable, Identifiable {
    case documents
    case photos
    case music
    case code
    case finance
    case archive
    case favorite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .documents: return "Documents"
        case .photos: return "Photos"
        case .music: return "Music"
        case .code: return "Code"
        case .finance: return "Finance"
        case .archive: return "Archive"
        case .favorite: return "Favorite"
        }
    }

    var symbolName: String {
        switch self {
        case .documents: return "doc.text.fill"
        case .photos: return "photo.fill"
        case .music: return "music.note"
        case .code: return "curlybraces"
        case .finance: return "chart.bar.fill"
        case .archive: return "archivebox.fill"
        case .favorite: return "star.fill"
        }
    }

    var accentColor: RGBAColor {
        switch self {
        case .documents: return .init(red: 0.15, green: 0.48, blue: 0.97, alpha: 1)
        case .photos: return .init(red: 0.91, green: 0.25, blue: 0.47, alpha: 1)
        case .music: return .init(red: 0.78, green: 0.28, blue: 0.96, alpha: 1)
        case .code: return .init(red: 0.17, green: 0.68, blue: 0.32, alpha: 1)
        case .finance: return .init(red: 0.92, green: 0.59, blue: 0.12, alpha: 1)
        case .archive: return .init(red: 0.46, green: 0.56, blue: 0.67, alpha: 1)
        case .favorite: return .init(red: 0.95, green: 0.68, blue: 0.07, alpha: 1)
        }
    }
}

struct RGBAColor: Codable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red.clamped(to: 0 ... 1)
        self.green = green.clamped(to: 0 ... 1)
        self.blue = blue.clamped(to: 0 ... 1)
        self.alpha = alpha.clamped(to: 0 ... 1)
    }

    init(nsColor: NSColor) {
        let converted = nsColor.usingColorSpace(.extendedSRGB) ?? .systemBlue
        self.init(
            red: Double(converted.redComponent),
            green: Double(converted.greenComponent),
            blue: Double(converted.blueComponent),
            alpha: Double(converted.alphaComponent)
        )
    }

    init(swiftUIColor: Color) {
        self.init(nsColor: NSColor(swiftUIColor))
    }

    var nsColor: NSColor {
        NSColor(
            calibratedRed: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: CGFloat(alpha)
        )
    }

    var swiftUIColor: Color {
        Color(nsColor)
    }

    var hexString: String {
        let r = Int((red * 255).rounded())
        let g = Int((green * 255).rounded())
        let b = Int((blue * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    static let defaultTint = RGBAColor(nsColor: .systemBlue)
}

struct FolderCustomizationDraft: Equatable {
    var useTint: Bool = true
    var tintColor: RGBAColor = .defaultTint
    var overlayImageData: Data?
    var overlayMode: OverlayMode = .overlay
    var overlayOpacity: Double = 0.85

    var replacementMode: ReplacementMode = .none
    var selectedPreset: SystemIconPreset = .documents
    var customIconData: Data?

    var finderComment: String = ""
    var tagsText: String = ""

    static let `default` = FolderCustomizationDraft()

    var overlayImage: NSImage? {
        guard let overlayImageData else { return nil }
        return NSImage(data: overlayImageData)
    }

    var customIconImage: NSImage? {
        guard let customIconData else { return nil }
        return NSImage(data: customIconData)
    }

    var tags: [String] {
        let pieces = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var seen = Set<String>()
        return pieces.filter { seen.insert($0).inserted }
    }

    func toPersisted() -> PersistedCustomization {
        PersistedCustomization(
            useTint: useTint,
            tintColor: tintColor,
            overlayImageData: overlayImageData,
            overlayMode: overlayMode,
            overlayOpacity: overlayOpacity,
            replacementMode: replacementMode,
            selectedPreset: selectedPreset,
            customIconData: customIconData,
            finderComment: finderComment,
            tags: tags
        )
    }

    init() {}

    init(persisted: PersistedCustomization) {
        useTint = persisted.useTint
        tintColor = persisted.tintColor
        overlayImageData = persisted.overlayImageData
        overlayMode = persisted.overlayMode
        overlayOpacity = persisted.overlayOpacity
        replacementMode = persisted.replacementMode
        selectedPreset = persisted.selectedPreset
        customIconData = persisted.customIconData
        finderComment = persisted.finderComment
        tagsText = persisted.tags.joined(separator: ", ")
    }
}

struct PersistedCustomization: Codable {
    var useTint: Bool
    var tintColor: RGBAColor
    var overlayImageData: Data?
    var overlayMode: OverlayMode
    var overlayOpacity: Double

    var replacementMode: ReplacementMode
    var selectedPreset: SystemIconPreset
    var customIconData: Data?

    var finderComment: String
    var tags: [String]
}

struct SavedIconItem: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var imageData: Data
    var createdAt: Date
}

struct SavedColorItem: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var color: RGBAColor
    var createdAt: Date
}

struct SavedMetadataItem: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var finderComment: String
    var tags: [String]
    var createdAt: Date
}

struct SavedThemeItem: Codable, Identifiable {
    var id: UUID
    var name: String
    var customization: PersistedCustomization
    var previewIconData: Data
    var createdAt: Date
}

struct FolderSnapshot: Codable {
    var bookmarkData: Data
    var lastKnownPath: String
    var hadCustomIcon: Bool
    var originalCustomIconData: Data?
    var originalFinderCommentData: Data?
    var originalTagsData: Data?
    var originalConfigData: Data?
    var capturedAt: Date
}

enum FolderColorError: LocalizedError {
    case notAFolder(URL)
    case noSelectedFolder
    case noFolders
    case iconApplyFailed(URL)
    case permissionDenied(URL)
    case snapshotUnavailable(URL)
    case imageLoadFailed(URL)
    case metadataEncodingFailed(String)
    case metadataTooLarge(String)
    case xattrOperationFailed(name: String, code: Int32)

    var errorDescription: String? {
        switch self {
        case let .notAFolder(url):
            return "\(url.lastPathComponent) is not a folder."
        case .noSelectedFolder:
            return "Select a folder first."
        case .noFolders:
            return "Drop one or more folders to get started."
        case let .iconApplyFailed(url):
            return "Failed to apply the icon for \(url.lastPathComponent)."
        case let .permissionDenied(url):
            return "Permission denied for \(url.path)."
        case let .snapshotUnavailable(url):
            return "No saved snapshot is available for \(url.lastPathComponent)."
        case let .imageLoadFailed(url):
            return "Could not read image data from \(url.lastPathComponent)."
        case let .metadataEncodingFailed(field):
            return "Could not encode \(field) metadata."
        case let .metadataTooLarge(field):
            return "The \(field) data is too large to save as metadata."
        case let .xattrOperationFailed(name, code):
            return "Extended attribute operation failed for \(name). POSIX error: \(code)."
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
