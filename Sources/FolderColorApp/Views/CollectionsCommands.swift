import SwiftUI

struct CollectionsCommands: Commands {
    @ObservedObject var viewModel: FolderColorViewModel

    var body: some Commands {
        CommandMenu("Collections") {
            Button("Open Collections") {
                viewModel.openCollectionsPopup()
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])

            Button("Open Metadata") {
                viewModel.openMetadataPopup()
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
        }
    }
}
