import SwiftUI

struct FileGridView: View {
    let files: [UnifiedFile]
    @Binding var selectedFileIds: Set<String>
    let onDoubleClick: (UnifiedFile) -> Void
    let contextMenuItems: (UnifiedFile) -> AnyView
    var canCreateFolder: Bool = false
    var onNewFolder: (() -> Void)? = nil
    var onMoveToFolder: ((String, UnifiedFile) async -> Void)? = nil
    var onReorder: ((String, String) -> Void)? = nil
    var renamingFileId: String? = nil
    @Binding var renamingText: String
    var onRenameCommit: (() -> Void)? = nil
    var onRenameCancel: (() -> Void)? = nil

    @State private var dropTargetId: String?

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(files, id: \.uniqueId) { file in
                    FileGridCellView(
                        file: file,
                        isRenaming: renamingFileId == file.uniqueId,
                        renamingText: $renamingText,
                        onRenameCommit: onRenameCommit,
                        onRenameCancel: onRenameCancel
                    )
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedFileIds.contains(file.uniqueId) ? Color.accentColor.opacity(0.15) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedFileIds.contains(file.uniqueId) ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                        .overlay(dropHighlight(for: file))
                        .onTapGesture(count: 2) {
                            onDoubleClick(file)
                        }
                        .onTapGesture {
                            if NSEvent.modifierFlags.contains(.command) {
                                if selectedFileIds.contains(file.uniqueId) {
                                    selectedFileIds.remove(file.uniqueId)
                                } else {
                                    selectedFileIds.insert(file.uniqueId)
                                }
                            } else {
                                selectedFileIds = [file.uniqueId]
                            }
                        }
                        .draggable(file.uniqueId)
                        .dropDestination(for: String.self) { items, _ in
                            guard let draggedId = items.first, draggedId != file.uniqueId else { return false }
                            let idsToMove = selectedFileIds.contains(draggedId) ? selectedFileIds : [draggedId]
                            if file.isFolder {
                                if let onMoveToFolder {
                                    Task {
                                        for id in idsToMove where id != file.uniqueId {
                                            await onMoveToFolder(id, file)
                                        }
                                    }
                                }
                            } else {
                                onReorder?(draggedId, file.uniqueId)
                            }
                            dropTargetId = nil
                            return true
                        } isTargeted: { targeted in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if targeted {
                                    dropTargetId = file.uniqueId
                                } else if dropTargetId == file.uniqueId {
                                    dropTargetId = nil
                                }
                            }
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

    @ViewBuilder
    private func dropHighlight(for file: UnifiedFile) -> some View {
        if dropTargetId == file.uniqueId {
            if file.isFolder {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor.opacity(0.4), lineWidth: 1.5)
                    )
            } else {
                VStack(spacing: 0) {
                    Color.accentColor.frame(height: 2)
                    Spacer()
                }
            }
        }
    }
}
