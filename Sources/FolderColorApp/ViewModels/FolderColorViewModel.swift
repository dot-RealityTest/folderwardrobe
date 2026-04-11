import AppKit
import Foundation
import SwiftUI

@MainActor
final class FolderColorViewModel: ObservableObject {
    @Published var folders: [FolderTarget] = []
    @Published var selectedFolderID: FolderTarget.ID? {
        didSet {
            loadSelectedFolderState()
        }
    }

    @Published var draft: FolderCustomizationDraft = .default {
        didSet {
            refreshPreview()
        }
    }

    @Published var previewIcon: NSImage?
    @Published var currentIcon: NSImage?

    @Published var isShowingAlert: Bool = false
    @Published var alertMessage: String = ""

    @Published var statusMessage: String?
    @Published var isStatusError: Bool = false
    @Published var isShowingCollectionsPopup: Bool = false
    @Published var isShowingMetadataPopup: Bool = false
    @Published var pickerTintColor: Color = RGBAColor.defaultTint.swiftUIColor
    @Published var savedIcons: [SavedIconItem] = []
    @Published var savedColors: [SavedColorItem] = []
    @Published var savedMetadata: [SavedMetadataItem] = []
    @Published var savedThemes: [SavedThemeItem] = []
    @Published var metadataNameDraft: String = ""
    @Published var themeNameDraft: String = ""
    @Published var iconNameDraft: String = ""

    private let service: FolderCustomizationService
    private let libraryStore: CustomizationLibraryStore
    private var statusClearTask: Task<Void, Never>?

    init(
        service: FolderCustomizationService = FolderCustomizationService(),
        libraryStore: CustomizationLibraryStore = CustomizationLibraryStore()
    ) {
        self.service = service
        self.libraryStore = libraryStore
        savedIcons = libraryStore.loadIcons().sorted(by: { $0.createdAt > $1.createdAt })
        savedColors = libraryStore.loadColors().sorted(by: { $0.createdAt > $1.createdAt })
        savedMetadata = libraryStore.loadMetadataItems().sorted(by: { $0.createdAt > $1.createdAt })
        savedThemes = libraryStore.loadThemes().sorted(by: { $0.createdAt > $1.createdAt })
        pickerTintColor = draft.tintColor.swiftUIColor
        refreshPreview()
    }

    var selectedFolder: FolderTarget? {
        guard let selectedFolderID else { return nil }
        return folders.first(where: { $0.id == selectedFolderID })
    }

    func addFolders(from droppedURLs: [URL]) {
        var existingPaths = Set(folders.map(\.standardizedPath))
        var addedCount = 0

        for url in droppedURLs {
            let normalized = url.standardizedFileURL
            guard isDirectory(url: normalized) else {
                continue
            }

            if existingPaths.insert(normalized.path).inserted {
                folders.append(FolderTarget(url: normalized))
                addedCount += 1
            }
        }

        if selectedFolderID == nil {
            selectedFolderID = folders.first?.id
        }

        if addedCount > 0 {
            setStatus("Added \(addedCount) folder\(addedCount == 1 ? "" : "s").")
        } else {
            setStatus("Only folders can be dropped here.", isError: true)
        }
    }

    func removeSelectedFolder() {
        guard let selectedFolderID else { return }
        folders.removeAll { $0.id == selectedFolderID }
        self.selectedFolderID = folders.first?.id
        if folders.isEmpty {
            draft = .default
            currentIcon = nil
        }
    }

    func clearFolders() {
        folders.removeAll()
        selectedFolderID = nil
        draft = .default
        currentIcon = nil
        setStatus("Cleared folder list.")
    }

    func applyToSelectedFolder() {
        guard let folder = selectedFolder else {
            presentError(FolderColorError.noSelectedFolder)
            return
        }

        do {
            try service.apply(customization: draft, to: [folder.url])
            currentIcon = service.currentIcon(for: folder.url)
            setStatus("Applied customization to \(folder.displayName).")
        } catch {
            presentError(error)
        }
    }

    func applyToAllFolders() {
        guard !folders.isEmpty else {
            presentError(FolderColorError.noFolders)
            return
        }

        do {
            try service.apply(customization: draft, to: folders.map(\.url))
            if let selectedFolder {
                currentIcon = service.currentIcon(for: selectedFolder.url)
            }
            setStatus("Applied customization to \(folders.count) folder\(folders.count == 1 ? "" : "s").")
        } catch {
            presentError(error)
        }
    }

    func revertSelectedFolder() {
        guard let folder = selectedFolder else {
            presentError(FolderColorError.noSelectedFolder)
            return
        }

        do {
            try service.revert(folders: [folder.url])
            draft = .default
            currentIcon = service.currentIcon(for: folder.url)
            setStatus("Restored \(folder.displayName) to its original appearance.")
        } catch {
            presentError(error)
        }
    }

    func revertAllFolders() {
        guard !folders.isEmpty else {
            presentError(FolderColorError.noFolders)
            return
        }

        do {
            try service.revert(folders: folders.map(\.url))
            draft = .default
            if let selectedFolder {
                currentIcon = service.currentIcon(for: selectedFolder.url)
            }
            setStatus("Reverted \(folders.count) folder\(folders.count == 1 ? "" : "s").")
        } catch {
            presentError(error)
        }
    }

    func importCustomIcon(from url: URL) {
        do {
            guard let image = NSImage(contentsOf: url) else {
                throw FolderColorError.imageLoadFailed(url)
            }
            guard let pngData = normalizedImageData(from: image, maxBytes: 100_000) else {
                throw FolderColorError.metadataTooLarge("icon")
            }

            draft.customIconData = pngData
            draft.replacementMode = .customFile
            setStatus("Custom icon loaded.")
        } catch {
            presentError(error)
        }
    }

    func clearCustomIcon() {
        draft.customIconData = nil
        if draft.replacementMode == .customFile {
            draft.replacementMode = .none
        }
        setStatus("Custom icon cleared.")
    }

    func addCurrentCustomIconToLibrary() {
        guard let iconData = draft.customIconData else {
            setStatus("Choose a custom icon first.", isError: true)
            return
        }

        let proposedName = iconNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = proposedName.isEmpty ? "Icon \(savedIcons.count + 1)" : proposedName
        let item = SavedIconItem(id: UUID(), name: name, imageData: iconData, createdAt: Date())
        savedIcons.insert(item, at: 0)
        iconNameDraft = ""
        persistIcons()
        setStatus("Saved \(name) to icon library.")
    }

    func importIconToLibrary(from url: URL) {
        do {
            guard let image = NSImage(contentsOf: url) else {
                throw FolderColorError.imageLoadFailed(url)
            }
            guard let pngData = normalizedImageData(from: image, maxBytes: 100_000) else {
                throw FolderColorError.metadataTooLarge("icon")
            }

            let proposedName = iconNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallback = url.deletingPathExtension().lastPathComponent
            let name = proposedName.isEmpty ? (fallback.isEmpty ? "Icon \(savedIcons.count + 1)" : fallback) : proposedName
            let item = SavedIconItem(id: UUID(), name: name, imageData: pngData, createdAt: Date())
            savedIcons.insert(item, at: 0)
            iconNameDraft = ""
            persistIcons()

            draft.customIconData = pngData
            draft.replacementMode = .customFile
            setStatus("Added \(name) to icon library and selected it.")
        } catch {
            presentError(error)
        }
    }

    func applySavedIcon(_ item: SavedIconItem) {
        var selectedData = item.imageData

        if let image = NSImage(data: item.imageData), let normalized = normalizedImageData(from: image, maxBytes: 100_000) {
            selectedData = normalized
            if normalized != item.imageData, let index = savedIcons.firstIndex(where: { $0.id == item.id }) {
                savedIcons[index].imageData = normalized
                persistIcons()
            }
        }

        draft.customIconData = selectedData
        draft.replacementMode = .customFile
        setStatus("Applied icon: \(item.name).")
    }

    func removeSavedIcon(_ item: SavedIconItem) {
        savedIcons.removeAll(where: { $0.id == item.id })
        persistIcons()
        setStatus("Removed icon: \(item.name).")
    }

    func updateSavedIcon(_ item: SavedIconItem, with imageData: Data) {
        guard let image = NSImage(data: imageData) else {
            setStatus("Could not read cropped icon data.", isError: true)
            return
        }

        guard let normalized = normalizedImageData(from: image, maxBytes: 100_000) else {
            setStatus("Cropped icon is still too large. Try a tighter crop.", isError: true)
            return
        }

        guard let index = savedIcons.firstIndex(where: { $0.id == item.id }) else {
            setStatus("Icon could not be found in the library.", isError: true)
            return
        }

        savedIcons[index].imageData = normalized
        persistIcons()

        draft.customIconData = normalized
        draft.replacementMode = .customFile
        setStatus("Updated icon crop: \(item.name).")
    }

    func addCurrentColorToLibrary() {
        if savedColors.contains(where: { $0.color == draft.tintColor }) {
            setStatus("Color \(draft.tintColor.hexString) already exists.", isError: true)
            return
        }

        let name = "Color \(draft.tintColor.hexString)"
        let item = SavedColorItem(id: UUID(), name: name, color: draft.tintColor, createdAt: Date())
        savedColors.insert(item, at: 0)
        persistColors()
        setStatus("Saved \(name) to quick colors.")
    }

    func applySavedColor(_ item: SavedColorItem) {
        applyTintColor(item.color)
        setStatus("Applied color: \(item.name).")
    }

    func removeSavedColor(_ item: SavedColorItem) {
        savedColors.removeAll(where: { $0.id == item.id })
        persistColors()
        setStatus("Removed color: \(item.name).")
    }


    func addCurrentMetadataToLibrary() {
        _ = createMetadataCollection(
            name: metadataNameDraft,
            comment: draft.finderComment,
            tagsInput: draft.tagsText,
            clearNameDraftOnSuccess: true
        )
    }

    @discardableResult
    func createMetadataCollection(name: String, comment: String, tagsInput: String, clearNameDraftOnSuccess: Bool = false) -> Bool {
        let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        let tags = uniqueTags(from: tagsInput)

        guard !trimmedComment.isEmpty || !tags.isEmpty else {
            setStatus("Add a Finder comment or tags first.", isError: true)
            return false
        }

        if savedMetadata.contains(where: { $0.finderComment == trimmedComment && $0.tags == tags }) {
            setStatus("This metadata set already exists.", isError: true)
            return false
        }

        let proposedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let generatedName: String
        if !trimmedComment.isEmpty {
            generatedName = String(trimmedComment.prefix(28))
        } else if let firstTag = tags.first {
            generatedName = "Tags: \(firstTag)"
        } else {
            generatedName = "Metadata \(savedMetadata.count + 1)"
        }

        let resolvedName = proposedName.isEmpty ? generatedName : proposedName

        let item = SavedMetadataItem(
            id: UUID(),
            name: resolvedName,
            finderComment: trimmedComment,
            tags: tags,
            createdAt: Date()
        )

        savedMetadata.insert(item, at: 0)
        if clearNameDraftOnSuccess {
            metadataNameDraft = ""
        }
        persistMetadata()
        setStatus("Saved metadata: \(resolvedName).")
        return true
    }

    func applySavedMetadata(_ item: SavedMetadataItem) {
        draft.finderComment = item.finderComment
        draft.tagsText = item.tags.joined(separator: ", ")
        setStatus("Loaded metadata: \(item.name).")
    }


    func applySavedMetadataToSelectedFolder(_ item: SavedMetadataItem) {
        guard let folder = selectedFolder else {
            presentError(FolderColorError.noSelectedFolder)
            return
        }

        do {
            try service.applyMetadata(comment: item.finderComment, tags: item.tags, to: [folder.url])
            draft.finderComment = item.finderComment
            draft.tagsText = item.tags.joined(separator: ", ")
            currentIcon = service.currentIcon(for: folder.url)
            setStatus("Applied metadata to \(folder.displayName): \(item.name).")
        } catch {
            presentError(error)
        }
    }

    func removeSavedMetadata(_ item: SavedMetadataItem) {
        savedMetadata.removeAll(where: { $0.id == item.id })
        persistMetadata()
        setStatus("Removed metadata: \(item.name).")
    }

    func saveCurrentTheme() {
        let proposedName = themeNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = proposedName.isEmpty ? "Theme \(savedThemes.count + 1)" : proposedName
        var themeDraft = draft
        themeDraft.overlayImageData = nil
        themeDraft.overlayOpacity = 0.85
        themeDraft.overlayMode = .overlay

        let preview = service.previewIcon(for: themeDraft, size: 192)
        guard let previewData = preview.pngData(maxDimension: 192) else {
            setStatus("Could not generate theme preview.", isError: true)
            return
        }

        let item = SavedThemeItem(
            id: UUID(),
            name: name,
            customization: themeDraft.toPersisted(),
            previewIconData: previewData,
            createdAt: Date()
        )

        savedThemes.insert(item, at: 0)
        themeNameDraft = ""
        persistThemes()
        setStatus("Saved theme: \(name).")
    }

    func applySavedTheme(_ item: SavedThemeItem) {
        draft = FolderCustomizationDraft(persisted: item.customization)
        draft.overlayImageData = nil
        draft.overlayOpacity = 0.85
        draft.overlayMode = .overlay
        sanitizeLegacyReplacementMode()
        pickerTintColor = draft.tintColor.swiftUIColor
        setStatus("Loaded theme: \(item.name).")
    }

    func applyTintColor(_ color: RGBAColor) {
        draft.useTint = true
        draft.tintColor = color
        pickerTintColor = color.swiftUIColor
    }

    func updateTintFromPicker(_ color: Color) {
        draft.useTint = true
        draft.tintColor = RGBAColor(swiftUIColor: color)
    }

    func removeSavedTheme(_ item: SavedThemeItem) {
        savedThemes.removeAll(where: { $0.id == item.id })
        persistThemes()
        setStatus("Removed theme: \(item.name).")
    }

    func presetPreview(_ preset: SystemIconPreset) -> NSImage {
        service.presetPreview(for: preset)
    }

    func imageFromSavedIcon(_ item: SavedIconItem) -> NSImage? {
        NSImage(data: item.imageData)
    }

    func imageFromSavedTheme(_ item: SavedThemeItem) -> NSImage? {
        NSImage(data: item.previewIconData)
    }

    func openCollectionsPopup() {
        isShowingCollectionsPopup = true
    }

    func openMetadataPopup() {
        isShowingMetadataPopup = true
    }

    private func loadSelectedFolderState() {
        guard let folder = selectedFolder else {
            currentIcon = nil
            refreshPreview()
            return
        }

        currentIcon = service.currentIcon(for: folder.url)

        if let savedDraft = service.loadSavedDraft(for: folder.url) {
            draft = savedDraft
            draft.overlayImageData = nil
            draft.overlayOpacity = 0.85
            draft.overlayMode = .overlay
            sanitizeLegacyReplacementMode()
        } else {
            draft = .default
            let metadata = service.loadCurrentMetadata(for: folder.url)
            draft.finderComment = metadata.comment
            draft.tagsText = metadata.tags.joined(separator: ", ")
        }

        pickerTintColor = draft.tintColor.swiftUIColor
        refreshPreview()
    }

    private func refreshPreview() {
        previewIcon = service.previewIcon(for: draft)
    }


    private func sanitizeLegacyReplacementMode() {
        if draft.replacementMode == .systemPreset {
            draft.replacementMode = .none
        }
    }


    private func uniqueTags(from raw: String) -> [String] {
        let pieces = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var seen = Set<String>()
        return pieces.filter { seen.insert($0).inserted }
    }

    private func isDirectory(url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
        return values?.isDirectory == true
    }

    private func normalizedImageData(from image: NSImage, maxBytes: Int = 50_000) -> Data? {
        let longestEdge = max(image.size.width, image.size.height)
        var dimension = min(max(longestEdge, 128), 1024)

        while dimension >= 16 {
            if let data = image.pngData(maxDimension: dimension), data.count <= maxBytes {
                return data
            }
            dimension *= 0.75
        }

        return nil
    }

    private func presentError(_ error: Error) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        alertMessage = message
        isShowingAlert = true
        setStatus(message, isError: true)
    }

    private func setStatus(_ message: String, isError: Bool = false) {
        statusClearTask?.cancel()
        statusMessage = message
        isStatusError = isError

        statusClearTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            statusMessage = nil
        }
    }

    private func persistIcons() {
        do {
            try libraryStore.saveIcons(savedIcons)
        } catch {
            presentError(error)
        }
    }

    private func persistThemes() {
        do {
            try libraryStore.saveThemes(savedThemes)
        } catch {
            presentError(error)
        }
    }

    private func persistColors() {
        do {
            try libraryStore.saveColors(savedColors)
        } catch {
            presentError(error)
        }
    }


    private func persistMetadata() {
        do {
            try libraryStore.saveMetadataItems(savedMetadata)
        } catch {
            presentError(error)
        }
    }
}
