import SwiftUI
import UniformTypeIdentifiers

private enum CollectionsTab: String, CaseIterable, Identifiable {
    case icons = "Icons"
    case metadata = "Metadata"

    var id: String { rawValue }
}

struct CollectionsPopupView: View {
    @ObservedObject var viewModel: FolderColorViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: CollectionsTab = .icons
    @State private var showingLibraryIconImporter = false
    @State private var cropTarget: SavedIconItem?
    @State private var newMetadataName: String = ""
    @State private var newMetadataComment: String = ""
    @State private var newMetadataTags: String = ""

    private let cardColumns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Collections")
                        .font(.title2.weight(.semibold))
                    Text("Apply and manage saved icons and metadata")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            Picker("Collection", selection: $selectedTab) {
                ForEach(CollectionsTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            Group {
                switch selectedTab {
                case .icons:
                    iconsTab
                case .metadata:
                    metadataTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 520)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .controlBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .fileImporter(isPresented: $showingLibraryIconImporter, allowedContentTypes: iconFileTypes, allowsMultipleSelection: false) { result in
            if case let .success(urls) = result, let url = urls.first {
                viewModel.importIconToLibrary(from: url)
            }
        }
        .sheet(item: $cropTarget) { item in
            if let sourceImage = NSImage(data: item.imageData) {
                IconCropSheet(iconName: item.name, sourceImage: sourceImage) { croppedData in
                    viewModel.updateSavedIcon(item, with: croppedData)
                }
            } else {
                VStack(spacing: 12) {
                    Text("Could not load icon for crop")
                        .font(.headline)
                    Button("Close") {
                        cropTarget = nil
                    }
                }
                .padding(24)
                .frame(minWidth: 380, minHeight: 180)
            }
        }
    }

    private var iconsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button("Import Icon...") {
                    showingLibraryIconImporter = true
                }

                Button("Save Current Icon") {
                    viewModel.addCurrentCustomIconToLibrary()
                }
                .disabled(viewModel.draft.customIconData == nil)

                Spacer()
            }

            if viewModel.savedIcons.isEmpty {
                emptyState(title: "No saved icons yet", subtitle: "Import an icon file to build your icon library.")
            } else {
                ScrollView {
                    LazyVGrid(columns: cardColumns, spacing: 14) {
                        ForEach(viewModel.savedIcons) { item in
                            Button {
                                viewModel.applySavedIcon(item)
                            } label: {
                                VStack(spacing: 10) {
                                    if let image = viewModel.imageFromSavedIcon(item) {
                                        Image(nsImage: image)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 76, height: 76)
                                    }

                                    Text(item.name)
                                        .font(.callout.weight(.medium))
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(nsColor: .controlBackgroundColor))
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Crop...") {
                                    cropTarget = item
                                }

                                Divider()

                                Button("Delete \(item.name)", role: .destructive) {
                                    viewModel.removeSavedIcon(item)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private var metadataTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox("Create Metadata Collection") {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Collection Name (optional)", text: $newMetadataName)
                        .textFieldStyle(.roundedBorder)

                    TextField("Finder Comment", text: $newMetadataComment, axis: .vertical)
                        .lineLimit(2 ... 4)
                        .textFieldStyle(.roundedBorder)

                    TextField("Tags (comma separated)", text: $newMetadataTags)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button("Create Collection") {
                            let created = viewModel.createMetadataCollection(
                                name: newMetadataName,
                                comment: newMetadataComment,
                                tagsInput: newMetadataTags
                            )
                            if created {
                                newMetadataName = ""
                                newMetadataComment = ""
                                newMetadataTags = ""
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Spacer()

                        Button("Save Current Metadata") {
                            viewModel.addCurrentMetadataToLibrary()
                        }
                    }
                }
            }

            if viewModel.savedMetadata.isEmpty {
                emptyState(title: "No saved metadata yet", subtitle: "Create a metadata collection for future use, then apply it in one click.")
            } else {
                ScrollView {
                    LazyVGrid(columns: cardColumns, spacing: 14) {
                        ForEach(viewModel.savedMetadata) { item in
                            Button {
                                viewModel.applySavedMetadataToSelectedFolder(item)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(item.name)
                                        .font(.callout.weight(.semibold))
                                        .lineLimit(1)

                                    if !item.finderComment.isEmpty {
                                        Text(item.finderComment)
                                            .font(.caption)
                                            .lineLimit(2)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text("No Finder comment")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    if item.tags.isEmpty {
                                        Text("No tags")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text(item.tags.joined(separator: " • "))
                                            .font(.caption2)
                                            .lineLimit(2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(nsColor: .controlBackgroundColor))
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Apply to Selected Folder") {
                                    viewModel.applySavedMetadataToSelectedFolder(item)
                                }

                                Button("Load Metadata Only") {
                                    viewModel.applySavedMetadata(item)
                                }

                                Divider()

                                Button("Delete \(item.name)", role: .destructive) {
                                    viewModel.removeSavedMetadata(item)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private var iconFileTypes: [UTType] {
        var types: [UTType] = [.image]
        if let icns = UTType(filenameExtension: "icns") {
            types.append(icns)
        }
        return types
    }

    private func emptyState(title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [5]))
        )
    }
}


private struct IconCropSheet: View {
    let iconName: String
    let sourceImage: NSImage
    let onSave: (Data) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var zoom: Double = 1.0
    @State private var offsetX: Double = 0.0
    @State private var offsetY: Double = 0.0
    @State private var roundness: Double = IconCropSheet.defaultRoundness

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Crop Icon")
                .font(.title3.weight(.semibold))
            Text(iconName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Original")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(nsImage: sourceImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.secondary.opacity(0.08))
                        )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Group {
                        if let preview = roundedCroppedImage {
                            Image(nsImage: preview)
                                .resizable()
                                .scaledToFit()
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.secondary.opacity(0.08))
                                .overlay(Text("Invalid crop").font(.caption).foregroundStyle(.secondary))
                        }
                    }
                    .frame(width: 180, height: 180)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.secondary.opacity(0.08))
                    )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Zoom") {
                    Slider(value: $zoom, in: 1.0 ... 4.0)
                        .frame(width: 260)
                }

                LabeledContent("Horizontal") {
                    Slider(value: $offsetX, in: -1.0 ... 1.0)
                        .frame(width: 260)
                }

                LabeledContent("Vertical") {
                    Slider(value: $offsetY, in: -1.0 ... 1.0)
                        .frame(width: 260)
                }

                LabeledContent("Roundness") {
                    HStack(spacing: 10) {
                        Slider(value: $roundness, in: 0.0 ... 1.0)
                            .frame(width: 220)
                        Text(roundnessLabel)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Reset") {
                    zoom = 1.0
                    offsetX = 0.0
                    offsetY = 0.0
                    roundness = Self.defaultRoundness
                }

                Button("Apply Crop") {
                    guard let pngData = roundedCroppedImage?.pngData(maxDimension: 1024) else { return }
                    onSave(pngData)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(roundedCroppedImage == nil)
            }
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 420)
    }

    private var croppedImage: NSImage? {
        guard let sourceCG = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width = CGFloat(sourceCG.width)
        let height = CGFloat(sourceCG.height)
        guard width > 1, height > 1 else { return nil }

        let baseSide = min(width, height)
        let cropSide = max(16, baseSide / CGFloat(zoom))

        let centerOriginX = (width - cropSide) / 2
        let centerOriginY = (height - cropSide) / 2
        let maxShiftX = (width - cropSide) / 2
        let maxShiftY = (height - cropSide) / 2

        let originX = min(max(0, centerOriginX + CGFloat(offsetX) * maxShiftX), width - cropSide)
        let originY = min(max(0, centerOriginY + CGFloat(offsetY) * maxShiftY), height - cropSide)

        let cropRect = CGRect(x: originX, y: originY, width: cropSide, height: cropSide).integral
        guard let croppedCG = sourceCG.cropping(to: cropRect) else {
            return nil
        }

        return NSImage(cgImage: croppedCG, size: NSSize(width: cropRect.width, height: cropRect.height))
    }


    private static let minMaskExponent: CGFloat = 2.6
    private static let maxMaskExponent: CGFloat = 8.0
    private static let defaultMaskExponent: CGFloat = 5.0
    private static let defaultRoundness: Double = {
        let min = Double(minMaskExponent)
        let max = Double(maxMaskExponent)
        let def = Double(defaultMaskExponent)
        return (max - def) / (max - min)
    }()

    private var maskExponent: CGFloat {
        let min = Self.minMaskExponent
        let max = Self.maxMaskExponent
        return max - (max - min) * CGFloat(roundness)
    }

    private var roundnessLabel: String {
        "\(Int((roundness * 100).rounded()))%"
    }

    private var roundedCroppedImage: NSImage? {
        guard let croppedImage else { return nil }
        return macIconRoundedImage(from: croppedImage, exponent: maskExponent)
    }

    private func macIconRoundedImage(from image: NSImage, exponent: CGFloat) -> NSImage? {
        let side = Int(max(1, min(image.size.width, image.size.height)).rounded(.down))
        guard side > 0 else { return nil }
        guard let sourceCG = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        guard let context = CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        let rect = CGRect(x: 0, y: 0, width: side, height: side)
        context.clear(rect)
        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)
        context.interpolationQuality = .high
        context.addPath(macIconSquirclePath(in: rect, exponent: exponent))
        context.clip()
        context.draw(sourceCG, in: rect)

        guard let maskedCG = context.makeImage() else { return nil }
        return NSImage(cgImage: maskedCG, size: NSSize(width: side, height: side))
    }

    // Superellipse mask gives a native app-icon silhouette instead of a simple rounded rectangle.
    private func macIconSquirclePath(in rect: CGRect, exponent: CGFloat = 5.0, samples: Int = 240) -> CGPath {
        let path = CGMutablePath()
        let a = rect.width / 2
        let b = rect.height / 2
        let centerX = rect.midX
        let centerY = rect.midY

        for index in 0 ... samples {
            let t = (2 * CGFloat.pi * CGFloat(index)) / CGFloat(samples)
            let cosT = cos(t)
            let sinT = sin(t)
            let x = a * signedPower(cosT, 2 / exponent)
            let y = b * signedPower(sinT, 2 / exponent)
            let point = CGPoint(x: centerX + x, y: centerY + y)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }

    private func signedPower(_ value: CGFloat, _ exponent: CGFloat) -> CGFloat {
        let magnitude = pow(abs(value), exponent)
        return value >= 0 ? magnitude : -magnitude
    }
}
