import AppKit
import Foundation
import SwiftUI

@main
struct FolderWardrobeApp: App {
    @StateObject private var viewModel = FolderColorViewModel()
    @MainActor private static var didApplyCustomAppIcon = false

    var body: some Scene {
        WindowGroup("folderwardrobe") {
            ContentView(viewModel: viewModel)
                .task { @MainActor in
                    Self.applyCustomAppIconIfAvailable()
                }
        }
        .defaultSize(width: 780, height: 520)
        .commands {
            CollectionsCommands(viewModel: viewModel)
        }
    }

    @MainActor
    private static func applyCustomAppIconIfAvailable() {
        guard !didApplyCustomAppIcon else { return }
        didApplyCustomAppIcon = true

        let bundleIconCandidates: [URL?] = [
            Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
            Bundle.main.url(forResource: "icon", withExtension: "png")
        ]

        for candidate in bundleIconCandidates.compactMap({ $0 }) {
            if let image = NSImage(contentsOf: candidate) {
                NSApplication.shared.applicationIconImage = image
                return
            }
        }

        for candidate in projectIconCandidates() {
            if let image = NSImage(contentsOf: candidate) {
                NSApplication.shared.applicationIconImage = image
                return
            }
        }
    }

    private static func projectIconCandidates() -> [URL] {
        let fileManager = FileManager.default
        let iconsDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath)
            .appendingPathComponent("icons", isDirectory: true)

        let preferredNames = [
            "Image.png",
            "AppIcon.png",
            "icon.png",
            "AppIcon.icns",
            "icon.icns"
        ]

        var candidates: [URL] = []
        var seen = Set<String>()

        func appendIfNeeded(_ url: URL) {
            let key = url.standardizedFileURL.path
            if seen.insert(key).inserted {
                candidates.append(url)
            }
        }

        for name in preferredNames {
            let url = iconsDirectory.appendingPathComponent(name)
            if fileManager.fileExists(atPath: url.path) {
                appendIfNeeded(url)
            }
        }

        guard let contents = try? fileManager.contentsOfDirectory(
            at: iconsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return candidates
        }

        let supportedExtensions = Set(["png", "jpg", "jpeg", "icns"])
        let sortedByRecency = contents
            .filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { lhs, rhs in
                let leftDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rightDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return leftDate > rightDate
            }

        for url in sortedByRecency {
            appendIfNeeded(url)
        }

        return candidates
    }
}
