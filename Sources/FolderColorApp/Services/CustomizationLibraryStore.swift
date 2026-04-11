import Foundation

private struct IconLibraryPayload: Codable {
    var icons: [SavedIconItem] = []
}

private struct ThemeLibraryPayload: Codable {
    var themes: [SavedThemeItem] = []
}

private struct ColorLibraryPayload: Codable {
    var colors: [SavedColorItem] = []
}

private struct MetadataLibraryPayload: Codable {
    var metadataItems: [SavedMetadataItem] = []
}

final class CustomizationLibraryStore {
    private let iconsFileURL: URL
    private let themesFileURL: URL
    private let colorsFileURL: URL
    private let metadataFileURL: URL

    init(directoryName: String = "folderwardrobe") {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directoryURL = Self.resolveStoreDirectory(baseDirectory: appSupport, preferredName: directoryName)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        iconsFileURL = directoryURL.appendingPathComponent("icon-library.json")
        themesFileURL = directoryURL.appendingPathComponent("theme-library.json")
        colorsFileURL = directoryURL.appendingPathComponent("color-library.json")
        metadataFileURL = directoryURL.appendingPathComponent("metadata-library.json")
    }

    func loadIcons() -> [SavedIconItem] {
        guard
            let data = try? Data(contentsOf: iconsFileURL),
            let payload = try? JSONDecoder().decode(IconLibraryPayload.self, from: data)
        else {
            return []
        }

        return payload.icons
    }

    func saveIcons(_ icons: [SavedIconItem]) throws {
        let payload = IconLibraryPayload(icons: icons)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        try data.write(to: iconsFileURL, options: .atomic)
    }

    func loadThemes() -> [SavedThemeItem] {
        guard
            let data = try? Data(contentsOf: themesFileURL),
            let payload = try? JSONDecoder().decode(ThemeLibraryPayload.self, from: data)
        else {
            return []
        }

        return payload.themes
    }

    func saveThemes(_ themes: [SavedThemeItem]) throws {
        let payload = ThemeLibraryPayload(themes: themes)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        try data.write(to: themesFileURL, options: .atomic)
    }

    func loadColors() -> [SavedColorItem] {
        guard
            let data = try? Data(contentsOf: colorsFileURL),
            let payload = try? JSONDecoder().decode(ColorLibraryPayload.self, from: data)
        else {
            return []
        }

        return payload.colors
    }

    func saveColors(_ colors: [SavedColorItem]) throws {
        let payload = ColorLibraryPayload(colors: colors)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        try data.write(to: colorsFileURL, options: .atomic)
    }


    func loadMetadataItems() -> [SavedMetadataItem] {
        guard
            let data = try? Data(contentsOf: metadataFileURL),
            let payload = try? JSONDecoder().decode(MetadataLibraryPayload.self, from: data)
        else {
            return []
        }

        return payload.metadataItems
    }

    func saveMetadataItems(_ metadataItems: [SavedMetadataItem]) throws {
        let payload = MetadataLibraryPayload(metadataItems: metadataItems)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        try data.write(to: metadataFileURL, options: .atomic)
    }

    private static func resolveStoreDirectory(baseDirectory: URL, preferredName: String) -> URL {
        let fileManager = FileManager.default
        let preferredDirectory = baseDirectory.appendingPathComponent(preferredName, isDirectory: true)
        if fileManager.fileExists(atPath: preferredDirectory.path) {
            return preferredDirectory
        }

        let legacyDirectory = baseDirectory.appendingPathComponent("FolderColorUtility", isDirectory: true)
        if fileManager.fileExists(atPath: legacyDirectory.path) {
            return legacyDirectory
        }

        return preferredDirectory
    }
}
