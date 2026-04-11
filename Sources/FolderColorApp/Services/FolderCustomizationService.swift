import AppKit
import Foundation

final class FolderCustomizationService {
    private let renderer: FolderIconRenderer
    private let snapshotStore: SnapshotStore

    init(renderer: FolderIconRenderer = FolderIconRenderer(), snapshotStore: SnapshotStore = SnapshotStore()) {
        self.renderer = renderer
        self.snapshotStore = snapshotStore
    }

    func previewIcon(for customization: FolderCustomizationDraft, size: CGFloat = 256) -> NSImage {
        renderer.renderIcon(from: customization, size: size)
    }

    func presetPreview(for preset: SystemIconPreset, size: CGFloat = 96) -> NSImage {
        renderer.renderPresetPreview(for: preset, size: size)
    }

    func currentIcon(for folderURL: URL) -> NSImage {
        NSWorkspace.shared.icon(forFile: folderURL.path)
    }

    func loadCurrentMetadata(for folderURL: URL) -> (comment: String, tags: [String]) {
        let comment = (try? FinderCommentStore.read(at: folderURL)) ?? ""
        let tags = (try? FinderTagStore.read(at: folderURL)) ?? []
        return (comment, tags)
    }

    func loadSavedDraft(for folderURL: URL) -> FolderCustomizationDraft? {
        guard let customization = try? CustomMetadataStore.readCustomization(at: folderURL) else {
            return nil
        }

        return FolderCustomizationDraft(persisted: customization)
    }

    func apply(customization: FolderCustomizationDraft, to folders: [URL]) throws {
        for folder in folders {
            try ensureWritableFolder(folder)
            try ensureSnapshotExists(for: folder)

            let icon = renderer.renderIcon(from: customization, size: 512)
            guard NSWorkspace.shared.setIcon(icon, forFile: folder.path, options: []) else {
                throw FolderColorError.iconApplyFailed(folder)
            }

            try FinderCommentStore.write(customization.finderComment, to: folder)
            try writeTags(customization.tags, to: folder)
            try CustomMetadataStore.writeCustomization(customization.toPersisted(), to: folder)
            NSWorkspace.shared.noteFileSystemChanged(folder.path)
        }
    }


    func applyMetadata(comment: String, tags: [String], to folders: [URL]) throws {
        for folder in folders {
            try ensureWritableFolder(folder)
            try ensureSnapshotExists(for: folder)

            try FinderCommentStore.write(comment, to: folder)
            try writeTags(tags, to: folder)

            var persisted = (try? CustomMetadataStore.readCustomization(at: folder)) ?? FolderCustomizationDraft.default.toPersisted()
            persisted.finderComment = comment
            persisted.tags = tags
            try CustomMetadataStore.writeCustomization(persisted, to: folder)

            NSWorkspace.shared.noteFileSystemChanged(folder.path)
        }
    }

    func revert(folders: [URL]) throws {
        for folder in folders {
            try ensureWritableFolder(folder)

            let key = folderKey(for: folder)
            guard let snapshot = snapshotStore.snapshot(for: key) else {
                throw FolderColorError.snapshotUnavailable(folder)
            }

            try restoreSnapshot(snapshot, to: folder)
            try snapshotStore.remove(for: key)
            NSWorkspace.shared.noteFileSystemChanged(folder.path)
        }
    }

    private func ensureWritableFolder(_ folderURL: URL) throws {
        let values = try folderURL.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory == true else {
            throw FolderColorError.notAFolder(folderURL)
        }

        guard FileManager.default.isWritableFile(atPath: folderURL.path) else {
            throw FolderColorError.permissionDenied(folderURL)
        }
    }

    private func ensureSnapshotExists(for folderURL: URL) throws {
        let key = folderKey(for: folderURL)
        guard snapshotStore.snapshot(for: key) == nil else {
            return
        }

        let values = try folderURL.resourceValues(forKeys: [.customIconKey])
        let customIconImage = values.customIcon

        let snapshot = FolderSnapshot(
            bookmarkData: try folderURL.bookmarkData(),
            lastKnownPath: folderURL.path,
            hadCustomIcon: customIconImage != nil,
            originalCustomIconData: customIconImage?.tiffRepresentation,
            originalFinderCommentData: try ExtendedAttributeStore.readData(name: FinderCommentStore.attributeName, at: folderURL),
            originalTagsData: try ExtendedAttributeStore.readData(name: FinderTagStore.attributeName, at: folderURL),
            originalConfigData: try CustomMetadataStore.readRawCustomizationData(at: folderURL),
            capturedAt: Date()
        )

        try snapshotStore.save(snapshot, for: key)
    }

    private func restoreSnapshot(_ snapshot: FolderSnapshot, to folderURL: URL) throws {
        if snapshot.hadCustomIcon, let iconData = snapshot.originalCustomIconData, let iconImage = NSImage(data: iconData) {
            guard NSWorkspace.shared.setIcon(iconImage, forFile: folderURL.path, options: []) else {
                throw FolderColorError.iconApplyFailed(folderURL)
            }
        } else {
            guard NSWorkspace.shared.setIcon(nil, forFile: folderURL.path, options: []) else {
                throw FolderColorError.iconApplyFailed(folderURL)
            }
        }

        try ExtendedAttributeStore.writeData(snapshot.originalFinderCommentData, name: FinderCommentStore.attributeName, at: folderURL)
        try ExtendedAttributeStore.writeData(snapshot.originalTagsData, name: FinderTagStore.attributeName, at: folderURL)
        try CustomMetadataStore.writeRawCustomizationData(snapshot.originalConfigData, to: folderURL)
    }

    private func writeTags(_ tags: [String], to folderURL: URL) throws {
        try FinderTagStore.write(tags, to: folderURL)
    }

    private func folderKey(for folderURL: URL) -> String {
        if
            let values = try? folderURL.resourceValues(forKeys: [.fileResourceIdentifierKey]),
            let identifier = values.fileResourceIdentifier
        {
            return "file-id:\(String(describing: identifier))"
        }

        return "path:\(folderURL.standardizedFileURL.path)"
    }
}
