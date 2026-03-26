import SwiftUI
import QuickLookUI

struct FileListView: View {
    let viewModel: FileListViewModel
    @Binding var selectedFileIds: Set<String>
    var favoritesVM: FavoritesViewModel?
    var frecencyVM: FrecencyViewModel?
    @State private var quickLookURL: URL?
    @State private var isDownloading = false
    @State private var dropTargetId: String?

    private var selectedFile: UnifiedFile? {
        guard let id = selectedFileIds.first else { return nil }
        return viewModel.files.first { $0.uniqueId == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Breadcrumb bar
            if viewModel.breadcrumbs.count > 1 || viewModel.hasCustomOrder {
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
                    if viewModel.hasCustomOrder {
                        Button {
                            viewModel.resetSortOrder()
                        } label: {
                            Label("Reset Order", systemImage: "arrow.up.arrow.down")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 12)
                    }
                }
                .background(.bar)
            }

            // File list
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
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("This folder is empty")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ZStack(alignment: .top) {
                    List(viewModel.files, id: \.uniqueId, selection: $selectedFileIds) { file in
                        FileRowView(file: file)
                            .tag(file.uniqueId)
                            .listRowBackground(dropHighlight(for: file))
                            .draggable(file.uniqueId)
                            .dropDestination(for: String.self) { items, _ in
                                guard let draggedId = items.first, draggedId != file.uniqueId else { return false }
                                // If dragged item is in selection, operate on all selected items
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
                    .onKeyPress(.return) {
                        if let file = selectedFile {
                            handleDoubleClick(file)
                        }
                        return .handled
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
        }
        .onChange(of: quickLookURL) { _, url in
            // Quick Look is handled by opening the temp file directly
            if let url {
                NSWorkspace.shared.open(url)
                quickLookURL = nil
            }
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
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private func contextMenuItems(for file: UnifiedFile) -> some View {
        if file.isFolder {
            Button("Open Folder") {
                Task { await viewModel.navigateIntoFolder(file) }
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

        let downloadURL = GraphEndpoints.driveItemContent(driveId: file.driveId, itemId: file.itemId)

        do {
            let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            let destinationURL = downloadsDir.appendingPathComponent(file.name)

            // Use URLSession to download (the Graph API returns a 302 redirect)
            let (tempURL, _) = try await URLSession.shared.download(from: downloadURL)
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)

            // Reveal in Finder
            NSWorkspace.shared.selectFile(destinationURL.path, inFileViewerRootedAtPath: downloadsDir.path)
        } catch {
            print("Download failed: \(error.localizedDescription)")
        }
    }

    private func quickLook(_ file: UnifiedFile) async {
        frecencyVM?.recordAccess(for: file)
        let downloadURL = GraphEndpoints.driveItemContent(driveId: file.driveId, itemId: file.itemId)

        do {
            let tempDir = FileManager.default.temporaryDirectory
            let tempFile = tempDir.appendingPathComponent(file.name)

            let (tempURL, _) = try await URLSession.shared.download(from: downloadURL)

            // Remove existing temp file if any
            try? FileManager.default.removeItem(at: tempFile)
            try FileManager.default.moveItem(at: tempURL, to: tempFile)

            quickLookURL = tempFile
        } catch {
            print("Quick Look failed: \(error.localizedDescription)")
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
