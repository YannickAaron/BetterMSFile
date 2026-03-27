import SwiftUI
import QuickLookUI
import UniformTypeIdentifiers

struct FileListView: View {
    let viewModel: FileListViewModel
    @Binding var selectedFileIds: Set<String>
    var favoritesVM: FavoritesViewModel?
    var frecencyVM: FrecencyViewModel?
    @State private var quickLookURL: URL?
    @State private var isDownloading = false
    @State private var dropTargetId: String?
    @State private var showNewFolderAlert = false
    @State private var newFolderName = ""
    @State private var showDeleteConfirmation = false
    @State private var itemsToDelete: Set<String> = []
    @State private var operationError: String?
    @State private var renamingFileId: String?
    @State private var renamingText = ""
    @State private var isDropTargeted = false

    private var selectedFile: UnifiedFile? {
        guard let id = selectedFileIds.first else { return nil }
        return viewModel.files.first { $0.uniqueId == id }
    }

    var body: some View {
        mainContent
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                handleFileDrop(providers)
            }
            .onChange(of: quickLookURL) { _, url in
            if let url {
                NSWorkspace.shared.open(url)
                quickLookURL = nil
            }
        }
        .alert("New Folder", isPresented: $showNewFolderAlert) {
            TextField("Folder name", text: $newFolderName)
            Button("Create") { createNewFolder() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            deleteConfirmationTitle,
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Error", isPresented: .init(
            get: { operationError != nil },
            set: { if !$0 { operationError = nil } }
        )) {
            Button("OK") { operationError = nil }
        } message: {
            Text(operationError ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .createNewFolder)) { _ in
            if viewModel.canCreateFolder {
                newFolderName = ""
                showNewFolderAlert = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .renameSelectedFile)) { _ in
            if selectedFileIds.count == 1, let file = selectedFile {
                startRename(file)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickLookFile)) { notification in
            if let uniqueId = notification.object as? String,
               let file = viewModel.files.first(where: { $0.uniqueId == uniqueId }),
               !file.isFolder {
                Task { await quickLook(file) }
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ZStack {
            VStack(spacing: 0) {
                breadcrumbBar
                fileListContent
                statusBar
            }
            dropZoneOverlay
            uploadProgressOverlay
        }
    }

    @ViewBuilder
    private var dropZoneOverlay: some View {
        if isDropTargeted && viewModel.canCreateFolder {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8]))
                .background(Color.accentColor.opacity(0.08))
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.up.doc")
                            .font(.largeTitle)
                        Text("Drop to upload")
                            .font(.headline)
                    }
                    .foregroundStyle(Color.accentColor)
                }
                .padding(8)
        }
    }

    @ViewBuilder
    private var uploadProgressOverlay: some View {
        if viewModel.isUploading {
            VStack {
                Spacer()
                uploadProgressView
                    .padding()
            }
        }
    }

    // MARK: - Status Bar

    @ViewBuilder
    private var statusBar: some View {
        if !viewModel.files.isEmpty {
            HStack {
                let fileCount = viewModel.files.filter { !$0.isFolder }.count
                let folderCount = viewModel.files.filter { $0.isFolder }.count
                let parts = [
                    folderCount > 0 ? "\(folderCount) folder\(folderCount == 1 ? "" : "s")" : nil,
                    fileCount > 0 ? "\(fileCount) file\(fileCount == 1 ? "" : "s")" : nil
                ].compactMap { $0 }
                Text(parts.joined(separator: ", "))

                if selectedFileIds.count > 1 {
                    Text("— \(selectedFileIds.count) selected")
                }

                Spacer()

                if viewModel.isRefreshing {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.bar)
        }
    }

    // MARK: - Breadcrumb Bar

    @ViewBuilder
    private var breadcrumbBar: some View {
        if viewModel.breadcrumbs.count > 1 || viewModel.hasCustomOrder || viewModel.canCreateFolder {
            HStack {
                if viewModel.breadcrumbs.count > 1 {
                    BreadcrumbBar(
                        breadcrumbs: viewModel.breadcrumbs,
                        onSelect: { crumb in
                            Task { await viewModel.navigateToBreadcrumb(crumb) }
                        },
                        onMoveToFolder: { draggedId, driveId, folderId in
                            Task {
                                try? await viewModel.moveFileToBreadcrumbFolder(
                                    fileId: draggedId, driveId: driveId, folderId: folderId
                                )
                            }
                        }
                    )
                }
                Spacer()
                // View mode toggle
                HStack(spacing: 2) {
                    Button {
                        viewModel.viewMode = .list
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(viewModel.viewMode == .list ? .primary : .secondary)

                    Button {
                        viewModel.viewMode = .grid
                    } label: {
                        Image(systemName: "square.grid.2x2")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(viewModel.viewMode == .grid ? .primary : .secondary)
                }
                .padding(.trailing, 4)

                if viewModel.hasCustomOrder {
                    Button {
                        viewModel.resetSortOrder()
                    } label: {
                        Label("Reset Order", systemImage: "arrow.up.arrow.down")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 4)
                }
                if viewModel.canCreateFolder {
                    Button { showUploadPicker() } label: {
                        Label("Upload", systemImage: "arrow.up.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 4)

                    Button {
                        newFolderName = ""
                        showNewFolderAlert = true
                    } label: {
                        Label("New Folder", systemImage: "folder.badge.plus")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 12)
                }
            }
            .background(.bar)
        }
    }

    // MARK: - File List Content

    @ViewBuilder
    private var fileListContent: some View {
        if viewModel.isLoading && viewModel.files.isEmpty {
            VStack(spacing: 8) {
                ProgressView()
                Text("Loading...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(error)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.files.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "folder")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("This folder is empty")
                    .foregroundStyle(.secondary)
                if viewModel.canCreateFolder {
                    HStack(spacing: 12) {
                        Button {
                            showUploadPicker()
                        } label: {
                            Label("Upload Files", systemImage: "arrow.up.doc")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            newFolderName = ""
                            showNewFolderAlert = true
                        } label: {
                            Label("New Folder", systemImage: "folder.badge.plus")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contextMenu {
                if viewModel.canCreateFolder {
                    Button("New Folder") {
                        newFolderName = ""
                        showNewFolderAlert = true
                    }
                }
            }
        } else if viewModel.viewMode == .grid {
            populatedGridView
        } else {
            populatedFileList
        }
    }

    @ViewBuilder
    private var populatedGridView: some View {
        ZStack(alignment: .top) {
            FileGridView(
                files: viewModel.files,
                selectedFileIds: $selectedFileIds,
                onDoubleClick: { file in handleDoubleClick(file) },
                contextMenuItems: { file in AnyView(contextMenuItems(for: file)) }
            )

            if viewModel.isLoading || viewModel.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .padding(6)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(4)
            }
        }
    }

    @ViewBuilder
    private var populatedFileList: some View {
        ZStack(alignment: .top) {
            List(viewModel.files, id: \.uniqueId, selection: $selectedFileIds) { file in
                fileRow(for: file)
                    .tag(file.uniqueId)
                    .listRowBackground(dropHighlight(for: file))
                    .draggable(file.uniqueId)
                    .dropDestination(for: String.self) { items, _ in
                        guard let draggedId = items.first, draggedId != file.uniqueId else { return false }
                        let idsToMove = selectedFileIds.contains(draggedId) ? selectedFileIds : [draggedId]
                        if file.isFolder {
                            Task {
                                for id in idsToMove where id != file.uniqueId {
                                    await moveFile(draggedId: id, intoFolder: file)
                                }
                            }
                        } else {
                            viewModel.reorderFile(draggedId: draggedId, targetId: file.uniqueId)
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
            }
            .onKeyPress(.escape) {
                Task { await viewModel.navigateBack() }
                return .handled
            }
            .onKeyPress(.space) {
                if let file = selectedFile, !file.isFolder {
                    Task { await quickLook(file) }
                }
                return .handled
            }
            .contextMenu(forSelectionType: String.self) { ids in
                if let id = ids.first,
                   let file = viewModel.files.first(where: { $0.uniqueId == id }) {
                    contextMenuItems(for: file)
                }
            } primaryAction: { ids in
                if let id = ids.first,
                   let file = viewModel.files.first(where: { $0.uniqueId == id }) {
                    handleDoubleClick(file)
                }
            }

            if viewModel.isLoading || viewModel.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .padding(6)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(4)
            }

            if isDownloading {
                HStack {
                    Spacer()
                    Label("Downloading...", systemImage: "arrow.down.circle")
                        .padding(8)
                        .background(.regularMaterial)
                        .clipShape(Capsule())
                    Spacer()
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Row Builder

    @ViewBuilder
    private func fileRow(for file: UnifiedFile) -> some View {
        if renamingFileId == file.uniqueId {
            FileRowView(
                file: file,
                isRenaming: true,
                renamingText: $renamingText,
                onRenameCommit: { commitRename() },
                onRenameCancel: { cancelRename() }
            )
        } else {
            FileRowView(file: file)
        }
    }

    // MARK: - Drag-and-Drop Visual Feedback

    @ViewBuilder
    private func dropHighlight(for file: UnifiedFile) -> some View {
        if dropTargetId == file.uniqueId {
            if file.isFolder {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.15))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor.opacity(0.4), lineWidth: 1.5))
            } else {
                VStack(spacing: 0) {
                    Color.accentColor.frame(height: 2)
                    Spacer()
                }
            }
        } else {
            Color.clear
        }
    }

    private func moveFile(draggedId: String, intoFolder folder: UnifiedFile) async {
        guard let file = viewModel.files.first(where: { $0.uniqueId == draggedId }),
              !file.isFolder else { return }

        viewModel.optimisticallyRemoveFile(draggedId)

        do {
            try await viewModel.moveFileToFolder(file: file, folder: folder)
        } catch {
            viewModel.rollbackRemoveFile(file)
            operationError = error.localizedDescription
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private func contextMenuItems(for file: UnifiedFile) -> some View {
        if viewModel.canCreateFolder {
            Button("New Folder") {
                newFolderName = ""
                showNewFolderAlert = true
            }

            Divider()
        }

        if file.isFolder {
            Button("Open Folder") {
                Task { await viewModel.navigateIntoFolder(file) }
            }
            Button("Open in New Tab") {
                NotificationCenter.default.post(name: .openInNewTab, object: file)
            }
        } else {
            // Open in native app if applicable
            if let msIcon = MSAppIcon.forFile(mimeType: file.mimeType, fileName: file.name),
               MSAppIcon.isNativeAppAvailable(for: file) {
                Button("Open in \(msIcon.appName)") {
                    MSAppIcon.openInNativeApp(file: file)
                }
            }

            Button("Open in Browser") {
                openInBrowser(file)
            }
        }

        Divider()

        Button("Copy Link") {
            copyLink(file)
        }

        if !file.isFolder {
            Button("Download") {
                Task { await downloadFile(file) }
            }

            Divider()

            Button("Quick Look") {
                Task { await quickLook(file) }
            }
        }

        if let favoritesVM {
            Divider()
            Button(favoritesVM.isFavorite(file) ? "Remove from Favorites" : "Add to Favorites") {
                favoritesVM.toggleFavorite(for: file)
            }
        }

        Divider()

        Button("Rename") {
            startRename(file)
        }

        Button("Delete", role: .destructive) {
            // If the right-clicked item is in the multi-selection, delete all selected
            let ids = selectedFileIds.contains(file.uniqueId) ? selectedFileIds : [file.uniqueId]
            itemsToDelete = ids
            showDeleteConfirmation = true
        }
    }

    private var deleteConfirmationTitle: String {
        if itemsToDelete.count == 1,
           let id = itemsToDelete.first,
           let file = viewModel.files.first(where: { $0.uniqueId == id }) {
            return "Delete \"\(file.name)\"?"
        }
        return "Delete \(itemsToDelete.count) items?"
    }

    private func handleDoubleClick(_ file: UnifiedFile) {
        frecencyVM?.recordAccess(for: file)
        if file.isFolder {
            Task { await viewModel.navigateIntoFolder(file) }
        } else {
            openInBrowser(file)
        }
    }

    private func openInBrowser(_ file: UnifiedFile) {
        frecencyVM?.recordAccess(for: file)
        if let url = URL(string: file.webURL) {
            NSWorkspace.shared.open(url)
        }
    }

    private func copyLink(_ file: UnifiedFile) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(file.webURL, forType: .string)
    }

    private func downloadFile(_ file: UnifiedFile) async {
        isDownloading = true
        defer { isDownloading = false }

        do {
            guard let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
                operationError = "Could not locate Downloads folder."
                return
            }
            var destinationURL = downloadsDir.appendingPathComponent(file.name)

            // Resolve file name collisions
            destinationURL = uniqueFileURL(destinationURL)

            let tempURL = try await viewModel.downloadFile(driveId: file.driveId, itemId: file.itemId)
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)

            // Reveal in Finder
            NSWorkspace.shared.selectFile(destinationURL.path, inFileViewerRootedAtPath: downloadsDir.path)
        } catch {
            operationError = "Download failed: \(error.localizedDescription)"
        }
    }

    /// Generate a unique file path by appending a counter if the file already exists.
    private func uniqueFileURL(_ url: URL) -> URL {
        guard FileManager.default.fileExists(atPath: url.path) else { return url }

        let directory = url.deletingLastPathComponent()
        let stem = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension

        var counter = 1
        var candidate: URL
        repeat {
            let newName = ext.isEmpty ? "\(stem) (\(counter))" : "\(stem) (\(counter)).\(ext)"
            candidate = directory.appendingPathComponent(newName)
            counter += 1
        } while FileManager.default.fileExists(atPath: candidate.path)

        return candidate
    }

    // MARK: - Upload

    private func showUploadPicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.message = "Select files to upload"

        guard panel.runModal() == .OK else { return }
        Task { await viewModel.uploadFiles(panel.urls) }
    }

    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        guard viewModel.canCreateFolder else { return false }
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                }
            }
        }

        group.notify(queue: .main) {
            guard !urls.isEmpty else { return }
            Task { await viewModel.uploadFiles(urls) }
        }

        return true
    }

    @ViewBuilder
    private var uploadProgressView: some View {
        VStack(spacing: 4) {
            ForEach(viewModel.uploadQueue) { upload in
                HStack(spacing: 8) {
                    Image(systemName: upload.error != nil ? "xmark.circle.fill" : upload.isComplete ? "checkmark.circle.fill" : "arrow.up.circle")
                        .foregroundStyle(upload.error != nil ? Color.red : upload.isComplete ? Color.green : Color.accentColor)
                    Text(upload.filename)
                        .lineLimit(1)
                        .font(.caption)
                    Spacer()
                    if !upload.isComplete && upload.error == nil {
                        ProgressView(value: Double(upload.bytesUploaded), total: Double(upload.totalBytes))
                            .frame(width: 80)
                    }
                }
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 4)
    }

    // MARK: - Folder & Delete Helpers

    private func createNewFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let invalidChars = CharacterSet(charactersIn: "\"*:<>?/\\|#%")
        if name.rangeOfCharacter(from: invalidChars) != nil {
            operationError = "Folder names cannot contain: \" * : < > ? / \\ | # %"
            return
        }
        Task {
            do {
                try await viewModel.createFolder(name: name)
            } catch {
                operationError = error.localizedDescription
            }
        }
    }

    private func performDelete() {
        let ids = itemsToDelete
        Task {
            do {
                try await viewModel.deleteItems(ids)
                selectedFileIds.subtract(ids)
            } catch {
                operationError = error.localizedDescription
            }
        }
    }

    // MARK: - Rename

    private func startRename(_ file: UnifiedFile) {
        // Pre-select name without extension
        let name = file.name
        if !file.isFolder, let dotIndex = name.lastIndex(of: ".") {
            renamingText = String(name[name.startIndex..<dotIndex])
        } else {
            renamingText = name
        }
        renamingFileId = file.uniqueId
    }

    private func cancelRename() {
        renamingFileId = nil
        renamingText = ""
    }

    private func commitRename() {
        guard let fileId = renamingFileId,
              let file = viewModel.files.first(where: { $0.uniqueId == fileId }) else {
            cancelRename()
            return
        }

        // Reconstruct full name with extension
        var newName = renamingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else {
            cancelRename()
            return
        }

        // Preserve original extension for files
        if !file.isFolder, let dotIndex = file.name.lastIndex(of: ".") {
            let ext = String(file.name[dotIndex...])
            newName += ext
        }

        // No change — just cancel
        if newName == file.name {
            cancelRename()
            return
        }

        // Validate name
        let invalidChars = CharacterSet(charactersIn: "\"*:<>?/\\|#%")
        if newName.rangeOfCharacter(from: invalidChars) != nil {
            operationError = "Names cannot contain: \" * : < > ? / \\ | # %"
            cancelRename()
            return
        }

        // Check if extension changed
        let oldExt = (file.name as NSString).pathExtension
        let newExt = (newName as NSString).pathExtension
        if !file.isFolder && !oldExt.isEmpty && oldExt.lowercased() != newExt.lowercased() {
            // Extension changed — warn but still proceed (user entered full name override)
        }

        let capturedId = fileId
        cancelRename()

        Task {
            do {
                try await viewModel.renameFile(capturedId, to: newName)
            } catch {
                operationError = "Rename failed: \(error.localizedDescription)"
            }
        }
    }

    private func quickLook(_ file: UnifiedFile) async {
        do {
            let tempDir = FileManager.default.temporaryDirectory
            let tempFile = tempDir.appendingPathComponent(file.name)

            guard !Task.isCancelled else { return }
            let tempURL = try await viewModel.downloadFile(driveId: file.driveId, itemId: file.itemId)
            guard !Task.isCancelled else { return }

            // Remove existing temp file if any
            try? FileManager.default.removeItem(at: tempFile)
            try FileManager.default.moveItem(at: tempURL, to: tempFile)

            quickLookURL = tempFile
            // Record access only after successful preview
            frecencyVM?.recordAccess(for: file)
        } catch {
            operationError = "Quick Look failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Breadcrumb Bar

struct BreadcrumbBar: View {
    let breadcrumbs: [FileListViewModel.BreadcrumbItem]
    let onSelect: (FileListViewModel.BreadcrumbItem) -> Void
    var onMoveToFolder: ((String, String, String) -> Void)?
    @State private var highlightedCrumbId: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(breadcrumbs.enumerated()), id: \.element.id) { index, crumb in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Button(crumb.name) {
                        onSelect(crumb)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(index == breadcrumbs.count - 1 ? .primary : .secondary)
                    .font(.caption)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        highlightedCrumbId == crumb.id
                            ? RoundedRectangle(cornerRadius: 4).fill(Color.accentColor.opacity(0.2))
                            : nil
                    )
                    .dropDestination(for: String.self) { items, _ in
                        guard let draggedId = items.first,
                              index < breadcrumbs.count - 1,
                              let itemId = crumb.itemId else { return false }
                        onMoveToFolder?(draggedId, crumb.driveId, itemId)
                        return true
                    } isTargeted: { targeted in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if targeted && index < breadcrumbs.count - 1 && crumb.itemId != nil {
                                highlightedCrumbId = crumb.id
                            } else if highlightedCrumbId == crumb.id {
                                highlightedCrumbId = nil
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(.bar)
    }
}
