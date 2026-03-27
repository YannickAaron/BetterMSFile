import SwiftUI

struct FileGridView: View {
    let files: [UnifiedFile]
    @Binding var selectedFileIds: Set<String>
    let onDoubleClick: (UnifiedFile) -> Void
    let contextMenuItems: (UnifiedFile) -> AnyView
    var canCreateFolder: Bool = false
    var onNewFolder: (() -> Void)? = nil

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(files, id: \.uniqueId) { file in
                    FileGridCellView(file: file)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedFileIds.contains(file.uniqueId) ? Color.accentColor.opacity(0.15) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedFileIds.contains(file.uniqueId) ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                        .onTapGesture {
                            selectedFileIds = [file.uniqueId]
                        }
                        .onTapGesture(count: 2) {
                            onDoubleClick(file)
                        }
                        .contextMenu {
                            contextMenuItems(file)
                        }
                }
            }
            .padding(12)
        }
        .contextMenu {
            if canCreateFolder, let onNewFolder {
                Button("New Folder") {
                    onNewFolder()
                }
            }
        }
    }
}
