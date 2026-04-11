import SwiftUI

struct DropZoneView: View {
    let onDropFolders: ([URL]) -> Void
    let onChooseFolders: () -> Void

    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 30))
                .foregroundStyle(isTargeted ? .blue : .secondary)

            Text("Drop Folders Here")
                .font(.headline)

            Text("Drag one or many folders into this area")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Choose Folder...") {
                onChooseFolders()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isTargeted ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isTargeted ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isTargeted ? 2 : 1)
        )
        .dropDestination(for: URL.self) { urls, _ in
            onDropFolders(urls)
            return true
        } isTargeted: { newValue in
            isTargeted = newValue
        }
    }
}
