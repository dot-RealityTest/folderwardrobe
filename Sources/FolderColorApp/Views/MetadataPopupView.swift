import SwiftUI

struct MetadataPopupView: View {
    @ObservedObject var viewModel: FolderColorViewModel
    @Environment(\.dismiss) private var dismiss

    private var tagPreview: [String] {
        viewModel.draft.tags
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Metadata")
                        .font(.title2.weight(.semibold))
                    Text("Edit Finder comment and tags, then save as a reusable collection item.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            GroupBox("Finder Comment") {
                TextField("Add a Finder comment", text: $viewModel.draft.finderComment, axis: .vertical)
                    .lineLimit(3 ... 6)
                    .textFieldStyle(.roundedBorder)
            }

            GroupBox("Tags") {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("tag1, tag2, important", text: $viewModel.draft.tagsText)
                        .textFieldStyle(.roundedBorder)

                    if !tagPreview.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(tagPreview, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(
                                            Capsule()
                                                .fill(Color.secondary.opacity(0.12))
                                        )
                                }
                            }
                        }
                    }
                }
            }

            GroupBox("Save To Collections") {
                HStack(spacing: 10) {
                    TextField("Name (optional)", text: $viewModel.metadataNameDraft)
                        .textFieldStyle(.roundedBorder)

                    Button("Save Metadata") {
                        viewModel.addCurrentMetadataToLibrary()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            HStack {
                Spacer()
                Button("Open Collections") {
                    dismiss()
                    viewModel.openCollectionsPopup()
                }
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 420)
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
    }
}
