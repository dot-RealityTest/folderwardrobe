import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var viewModel: FolderColorViewModel

    @State private var showingCustomIconImporter = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 260)
                .padding(14)

            Divider()

            detailPanel
        }
        .frame(minWidth: 700, minHeight: 460)
        .alert("Operation Failed", isPresented: $viewModel.isShowingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage)
        }
        .sheet(isPresented: $viewModel.isShowingCollectionsPopup) {
            CollectionsPopupView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isShowingMetadataPopup) {
            MetadataPopupView(viewModel: viewModel)
        }
        .onChange(of: viewModel.pickerTintColor) { newValue in
            viewModel.updateTintFromPicker(newValue)
        }
        .fileImporter(isPresented: $showingCustomIconImporter, allowedContentTypes: iconFileTypes, allowsMultipleSelection: false) { result in
            if case let .success(urls) = result, let url = urls.first {
                viewModel.importCustomIcon(from: url)
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Folders")
                .font(.title3.weight(.semibold))

            DropZoneView(
                onDropFolders: viewModel.addFolders(from:),
                onChooseFolders: openFolderPanel
            )

            List(selection: $viewModel.selectedFolderID) {
                ForEach(viewModel.folders) { folder in
                    folderRow(for: folder)
                        .listRowBackground(Color.clear)
                        .tag(folder.id)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 180)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            )

            HStack {
                Button("Remove") {
                    viewModel.removeSelectedFolder()
                }
                .disabled(viewModel.selectedFolder == nil)

                Button("Clear") {
                    viewModel.clearFolders()
                }
                .disabled(viewModel.folders.isEmpty)
            }
        }
    }

    @ViewBuilder
    private var detailPanel: some View {
        if let selectedFolder = viewModel.selectedFolder {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    previewSection(for: selectedFolder)
                    colorSection
                    iconReplacementSection
                    actionSection

                    if let statusMessage = viewModel.statusMessage {
                        Text(statusMessage)
                            .font(.callout)
                            .foregroundStyle(viewModel.isStatusError ? .red : .green)
                            .padding(.top, 4)
                    }
                }
                .padding(20)
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "folder")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)

                Text("Drop and select a folder to begin")
                    .font(.headline)

                Text("Use the menu bar: Collections > Open Collections or Open Metadata.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(20)
        }
    }

    private func previewSection(for folder: FolderTarget) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text(folder.displayName)
                    .font(.headline)
                Text(folder.url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                HStack(spacing: 18) {
                    iconCard(title: "Current", image: viewModel.currentIcon)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                    iconCard(title: "Preview", image: viewModel.previewIcon)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func iconCard(title: String, image: NSImage?) -> some View {
        VStack(spacing: 8) {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 120, height: 120)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 120, height: 120)
            }

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var colorSection: some View {
        GroupBox("Color") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Enable Folder Tint", isOn: $viewModel.draft.useTint)

                ColorPicker("Folder Color", selection: $viewModel.pickerTintColor, supportsOpacity: false)
                    .disabled(!viewModel.draft.useTint)

                HStack {
                    Button("Save Current Color") {
                        viewModel.addCurrentColorToLibrary()
                    }

                    Spacer()
                }

                if !viewModel.savedColors.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(viewModel.savedColors) { item in
                            colorCircle(item.color)
                                .contextMenu {
                                    Button("Delete \(item.name)") {
                                        viewModel.removeSavedColor(item)
                                    }
                                }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func colorCircle(_ color: RGBAColor) -> some View {
        Button {
            viewModel.applyTintColor(color)
        } label: {
            Circle()
                .fill(color.swiftUIColor)
                .frame(width: 18, height: 18)
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(viewModel.draft.tintColor == color ? 0.8 : 0), lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }

    private var iconReplacementSection: some View {
        GroupBox("Folder Icon Source") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Source", selection: $viewModel.draft.replacementMode) {
                    ForEach(ReplacementMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)


                if viewModel.draft.replacementMode == .customFile {
                    HStack {
                        Button("Choose Custom Icon") {
                            showingCustomIconImporter = true
                        }

                        Button("Clear") {
                            viewModel.clearCustomIcon()
                        }
                        .disabled(viewModel.draft.customIconData == nil)

                        Spacer()

                        Button("Save To Icon Library") {
                            viewModel.addCurrentCustomIconToLibrary()
                        }
                        .disabled(viewModel.draft.customIconData == nil)

                        Button("Open Collections") {
                            viewModel.openCollectionsPopup()
                        }
                    }

                    if let customIcon = viewModel.draft.customIconImage {
                        Image(nsImage: customIcon)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var actionSection: some View {
        HStack {
            Button("Apply to Selected") {
                viewModel.applyToSelectedFolder()
            }
            .buttonStyle(.borderedProminent)

            Button("Apply to All") {
                viewModel.applyToAllFolders()
            }
            .disabled(viewModel.folders.isEmpty)

            Button("Metadata...") {
                viewModel.openMetadataPopup()
            }

            Spacer()

            Button("Revert Selected") {
                viewModel.revertSelectedFolder()
            }
            .disabled(viewModel.selectedFolder == nil)

            Button("Revert All") {
                viewModel.revertAllFolders()
            }
            .disabled(viewModel.folders.isEmpty)
        }
    }

    private func folderRow(for folder: FolderTarget) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: finderIcon(for: folder))
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)

            Text(folder.displayName)
                .font(.system(size: 15, weight: .medium))
                .lineLimit(1)
        }
        .padding(.vertical, 5)
        .help(folder.url.path)
    }

    private func finderIcon(for folder: FolderTarget) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: folder.url.path)
        icon.size = NSSize(width: 32, height: 32)
        return icon
    }

    private func openFolderPanel() {
        let panel = NSOpenPanel()
        panel.title = "Choose Folder"
        panel.prompt = "Add"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser

        if panel.runModal() == .OK {
            viewModel.addFolders(from: panel.urls)
        }
    }

    private var iconFileTypes: [UTType] {
        var types: [UTType] = [.image]
        if let icns = UTType(filenameExtension: "icns") {
            types.append(icns)
        }
        return types
    }
}
