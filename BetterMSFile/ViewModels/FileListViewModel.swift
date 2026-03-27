import Foundation
import SwiftData

@MainActor @Observable
final class FileListViewModel {
    private let fileService: FileService
    private var modelContext: ModelContext?

    var files: [UnifiedFile] = []
    var isLoading = false
    var isRefreshing = false
    var errorMessage: String?

    /// Navigation stack for folder drill-down.
    var breadcrumbs: [BreadcrumbItem] = []

    // webDavUrl is now fetched per-file from Graph API — no need for drive-level URL tracking

    /// The cache key for the currently displayed folder/view.
    var currentCacheKey: String?

    /// Whether the current view has a custom sort order.
    var hasCustomOrder: Bool {
        guard let key = currentCacheKey, let context = modelContext else { return false }
        let descriptor = FetchDescriptor<CustomSortOrder>(predicate: #Predicate { $0.folderKey == key })
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    /// Cache expiry: 15 minutes for file lists.
    private let cacheExpiry: TimeInterval = 15 * 60

    /// In-memory cache keyed by location.
    private var memoryCache: [String: (files: [UnifiedFile], cachedAt: Date)] = [:]

    struct BreadcrumbItem: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let driveId: String
        let itemId: String?
        let source: FileSource
    }

    init(fileService: FileService) {
        self.fileService = fileService
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    /// Signal loading state immediately (before async work starts).
    func setLoading() {
        files = []
        errorMessage = nil
        isLoading = true
    }

    // MARK: - Load operations (stale-while-revalidate)

    func loadMyDriveRoot() async {
        breadcrumbs = [BreadcrumbItem(name: "My Files", driveId: "", itemId: nil, source: .oneDrive)]
        await loadWithCache(
            cacheKey: "onedrive_root",
            fetch: { try await self.fileService.fetchMyDriveRoot() }
        )
    }

    func loadSharedWithMe() async {
        breadcrumbs = [BreadcrumbItem(name: "Shared with Me", driveId: "", itemId: nil, source: .shared)]
        await loadWithCache(
            cacheKey: "shared",
            fetch: { try await self.fileService.fetchSharedWithMe() }
        )
    }

    func loadRecentFiles() async {
        breadcrumbs = [BreadcrumbItem(name: "Recent", driveId: "", itemId: nil, source: .oneDrive)]
        await loadWithCache(
            cacheKey: "recent",
            fetch: { try await self.fileService.fetchRecentFiles() }
        )
    }

    func loadDriveRoot(driveId: String, source: FileSource) async {
        breadcrumbs = [BreadcrumbItem(name: source.displayName, driveId: driveId, itemId: nil, source: source)]
        await loadWithCache(
            cacheKey: "drive_\(driveId)",
            fetch: { try await self.fileService.fetchDriveRoot(driveId: driveId, source: source) }
        )
    }

    /// Show a Team's channels as navigable folders.
    func loadTeamChannels(_ channels: [TeamChannel], teamName: String, siteId: String) {
        let source = FileSource.sharePoint(siteName: teamName, siteId: siteId)
        breadcrumbs = [BreadcrumbItem(name: teamName, driveId: "", itemId: nil, source: source)]
        currentCacheKey = "team_\(siteId)"
        errorMessage = nil

        files = channels.map { channel in
            // Use driveId + folderId so navigateIntoFolder can load the channel's files
            UnifiedFile(
                itemId: channel.folderId,
                driveId: channel.driveId,
                name: channel.displayName,
                isFolder: true,
                source: .sharePoint(siteName: channel.teamName, siteId: channel.siteId)
            )
        }
        sortFiles()
        isLoading = false
        isRefreshing = false
    }

    /// Show a SharePoint site's document libraries as navigable folders.
    func loadSiteDrives(site: SharePointSite) {
        let siteName = site.displayName
        breadcrumbs = [BreadcrumbItem(name: siteName, driveId: "", itemId: nil, source: .sharePoint(siteName: siteName, siteId: site.id))]
        currentCacheKey = "site_\(site.id)"
        errorMessage = nil

        files = site.drives.map { drive in
            UnifiedFile(
                itemId: drive.id,
                driveId: drive.id,
                name: drive.name,
                isFolder: true,
                source: .sharePoint(siteName: drive.siteName, siteId: drive.siteId)
            )
        }
        sortFiles()
        isLoading = false
        isRefreshing = false
    }

    /// Navigate to a file's parent folder (jump to location from search).
    func navigateToFile(_ file: UnifiedFile) async {
        guard !file.driveId.isEmpty else { return }

        let source = file.source

        // Fetch the item to get its parentReference with the parent folder ID
        do {
            let item = try await fileService.fetchItem(driveId: file.driveId, itemId: file.itemId)
            if let parentId = item.parentReference?.id, !parentId.isEmpty {
                breadcrumbs = [
                    BreadcrumbItem(name: source.displayName, driveId: file.driveId, itemId: nil, source: source),
                    BreadcrumbItem(name: "...", driveId: file.driveId, itemId: parentId, source: source)
                ]
                await loadWithCache(
                    cacheKey: "folder_\(file.driveId)_\(parentId)",
                    fetch: { try await self.fileService.fetchFolderContents(driveId: file.driveId, itemId: parentId, source: source) }
                )
            } else {
                breadcrumbs = [BreadcrumbItem(name: source.displayName, driveId: file.driveId, itemId: nil, source: source)]
                await loadWithCache(
                    cacheKey: "drive_\(file.driveId)",
                    fetch: { try await self.fileService.fetchDriveRoot(driveId: file.driveId, source: source) }
                )
            }
        } catch {
            breadcrumbs = [BreadcrumbItem(name: source.displayName, driveId: file.driveId, itemId: nil, source: source)]
            await loadWithCache(
                cacheKey: "drive_\(file.driveId)",
                fetch: { try await self.fileService.fetchDriveRoot(driveId: file.driveId, source: source) }
            )
        }
    }

    func navigateIntoFolder(_ file: UnifiedFile) async {
        guard file.isFolder else { return }

        let source = file.source

        // Synthetic drive folders (from loadSiteDrives) have driveId == itemId.
        // Navigate into them as drive roots, not regular folders.
        if file.driveId == file.itemId {
            breadcrumbs.append(BreadcrumbItem(name: file.name, driveId: file.driveId, itemId: nil, source: source))
            await loadWithCache(
                cacheKey: "drive_\(file.driveId)",
                fetch: { try await self.fileService.fetchDriveRoot(driveId: file.driveId, source: source) }
            )
        } else {
            breadcrumbs.append(BreadcrumbItem(name: file.name, driveId: file.driveId, itemId: file.itemId, source: source))
            await loadWithCache(
                cacheKey: "folder_\(file.driveId)_\(file.itemId)",
                fetch: { try await self.fileService.fetchFolderContents(driveId: file.driveId, itemId: file.itemId, source: source) }
            )
        }
    }

    func navigateToBreadcrumb(_ crumb: BreadcrumbItem) async {
        guard let index = breadcrumbs.firstIndex(of: crumb) else { return }
        breadcrumbs = Array(breadcrumbs.prefix(through: index))

        if let itemId = crumb.itemId {
            await loadWithCache(
                cacheKey: "folder_\(crumb.driveId)_\(itemId)",
                fetch: { try await self.fileService.fetchFolderContents(driveId: crumb.driveId, itemId: itemId, source: crumb.source) }
            )
        } else {
            switch crumb.source {
            case .oneDrive:
                await loadMyDriveRoot()
            case .shared:
                await loadSharedWithMe()
            case .sharePoint:
                await loadDriveRoot(driveId: crumb.driveId, source: crumb.source)
            }
        }
    }

    func navigateBack() async {
        guard breadcrumbs.count > 1 else { return }
        let target = breadcrumbs[breadcrumbs.count - 2]
        await navigateToBreadcrumb(target)
    }

    // MARK: - Stale-while-revalidate

    private func loadWithCache(cacheKey: String, fetch: @escaping () async throws -> [UnifiedFile]) async {
        currentCacheKey = cacheKey
        errorMessage = nil

        // 1. Show cached data immediately if available
        if let cached = loadFromCache(key: cacheKey), !cached.isEmpty {
            files = cached
            sortFiles()

            // Check if cache is still fresh
            if let entry = memoryCache[cacheKey],
               Date.now.timeIntervalSince(entry.cachedAt) < cacheExpiry {
                return // Cache is fresh, no need to refresh
            }

            // Cache is stale — refresh in background
            isRefreshing = true
        } else {
            isLoading = true
        }

        // 2. Fetch fresh data from network
        do {
            let freshFiles = try await fetch()
            // Guard: user may have navigated away while we were fetching
            guard currentCacheKey == cacheKey else { return }
            saveToCache(files: freshFiles, key: cacheKey)
            files = freshFiles
            sortFiles()
        } catch {
            guard currentCacheKey == cacheKey else { return }
            // Only show error if we have no cached data
            if files.isEmpty {
                errorMessage = error.localizedDescription
            }
        }

        // Only clear loading state if we're still the active request
        guard currentCacheKey == cacheKey else { return }
        isLoading = false
        isRefreshing = false
    }

    // MARK: - Cache (in-memory + SwiftData persistence)

    private func loadFromCache(key: String) -> [UnifiedFile]? {
        guard let entry = memoryCache[key] else { return nil }
        return entry.files
    }

    private let maxCacheEntries = 50

    private func saveToCache(files: [UnifiedFile], key: String) {
        memoryCache[key] = (files: files, cachedAt: .now)

        // Evict oldest entries if cache grows too large
        if memoryCache.count > maxCacheEntries {
            let sorted = memoryCache.sorted { $0.value.cachedAt < $1.value.cachedAt }
            for entry in sorted.prefix(memoryCache.count - maxCacheEntries) {
                memoryCache.removeValue(forKey: entry.key)
            }
        }

        // Also persist to SwiftData for cross-launch cache
        guard let context = modelContext else { return }
        for file in files {
            file.lastCachedAt = .now
            context.insert(file)
        }
        try? context.save()
    }

    private func sortFiles() {
        // Check for custom sort order first
        if let key = currentCacheKey, let context = modelContext {
            let descriptor = FetchDescriptor<CustomSortOrder>(predicate: #Predicate { $0.folderKey == key })
            if let custom = (try? context.fetch(descriptor))?.first {
                let orderMap = Dictionary(uniqueKeysWithValues: custom.orderedIds.enumerated().map { ($1, $0) })
                let maxIndex = custom.orderedIds.count
                files.sort { a, b in
                    let indexA = orderMap[a.uniqueId] ?? maxIndex
                    let indexB = orderMap[b.uniqueId] ?? maxIndex
                    if indexA != indexB { return indexA < indexB }
                    // New files (not in custom order) go at the end, sorted alphabetically
                    return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                }
                return
            }
        }

        // Default sort: folders first, then alphabetical
        files.sort { a, b in
            if a.isFolder != b.isFolder { return a.isFolder }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    // MARK: - Create & Delete

    /// Whether the current location supports creating folders.
    var canCreateFolder: Bool {
        guard let crumb = breadcrumbs.last else { return false }
        return !crumb.driveId.isEmpty
    }

    /// Create a new folder in the current location.
    func createFolder(name: String) async throws {
        guard let crumb = breadcrumbs.last, !crumb.driveId.isEmpty else { return }

        let parentId = crumb.itemId ?? "root"
        let item = try await fileService.createFolder(driveId: crumb.driveId, parentId: parentId, name: name)
        let newFile = item.toUnifiedFile(source: crumb.source)

        files.append(newFile)
        sortFiles()
        invalidateCache(for: currentCacheKey)
    }

    /// Delete one or more files/folders.
    func deleteItems(_ ids: Set<String>) async throws {
        var firstError: Error?
        for id in ids {
            guard let file = files.first(where: { $0.uniqueId == id }) else { continue }
            do {
                try await fileService.deleteItem(driveId: file.driveId, itemId: file.itemId)
                files.removeAll { $0.uniqueId == id }
            } catch {
                if firstError == nil { firstError = error }
            }
        }
        invalidateCache(for: currentCacheKey)
        if let firstError { throw firstError }
    }

    // MARK: - Upload

    /// Upload state for tracking progress in the UI.
    struct UploadProgress: Identifiable {
        let id = UUID()
        let filename: String
        var bytesUploaded: Int64 = 0
        var totalBytes: Int64
        var isComplete = false
        var error: String?
    }

    var uploadQueue: [UploadProgress] = []
    var isUploading: Bool { !uploadQueue.isEmpty && uploadQueue.contains(where: { !$0.isComplete }) }

    /// Upload files from local URLs to the current folder.
    func uploadFiles(_ urls: [URL]) async {
        guard let crumb = breadcrumbs.last, !crumb.driveId.isEmpty else { return }
        let parentId = crumb.itemId ?? "root"
        let driveId = crumb.driveId
        let source = crumb.source
        let maxFileSize: Int64 = 4 * 1024 * 1024  // 4MB threshold

        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }

            let filename = url.lastPathComponent
            guard let fileData = try? Data(contentsOf: url) else { continue }
            let fileSize = Int64(fileData.count)

            let progressIndex = uploadQueue.count
            uploadQueue.append(UploadProgress(filename: filename, totalBytes: fileSize))

            do {
                if fileSize < maxFileSize {
                    // Simple upload
                    let contentType = mimeType(for: url) ?? "application/octet-stream"
                    let item = try await fileService.uploadSmall(
                        data: fileData,
                        filename: filename,
                        driveId: driveId,
                        parentId: parentId,
                        contentType: contentType
                    )
                    let newFile = item.toUnifiedFile(source: source)
                    if !files.contains(where: { $0.uniqueId == newFile.uniqueId }) {
                        files.append(newFile)
                        sortFiles()
                    }
                } else {
                    // Resumable upload
                    let session = try await fileService.createUploadSession(
                        driveId: driveId,
                        parentId: parentId,
                        filename: filename
                    )
                    guard let sessionURL = URL(string: session.uploadUrl) else {
                        throw GraphError.invalidResponse
                    }

                    let chunkSize = 5 * 1024 * 1024 // 5MB chunks
                    var offset = 0

                    while offset < fileData.count {
                        let end = min(offset + chunkSize, fileData.count)
                        let chunkData = fileData[offset..<end]
                        let range = "\(offset)-\(end - 1)"

                        let responseData = try await fileService.uploadChunk(
                            sessionURL: sessionURL,
                            data: Data(chunkData),
                            range: range,
                            totalSize: fileSize
                        )

                        offset = end
                        if progressIndex < uploadQueue.count {
                            uploadQueue[progressIndex].bytesUploaded = Int64(offset)
                        }

                        // Final chunk returns the completed item
                        if offset >= fileData.count {
                            if let item = try? JSONDecoder().decode(GraphDriveItem.self, from: responseData) {
                                let newFile = item.toUnifiedFile(source: source)
                                if !files.contains(where: { $0.uniqueId == newFile.uniqueId }) {
                                    files.append(newFile)
                                    sortFiles()
                                }
                            }
                        }
                    }
                }

                if progressIndex < uploadQueue.count {
                    uploadQueue[progressIndex].isComplete = true
                }
                invalidateCache(for: currentCacheKey)
            } catch {
                if progressIndex < uploadQueue.count {
                    uploadQueue[progressIndex].error = error.localizedDescription
                    uploadQueue[progressIndex].isComplete = true
                }
            }
        }

        // Clear completed uploads after a delay
        Task {
            try? await Task.sleep(for: .seconds(3))
            uploadQueue.removeAll(where: { $0.isComplete })
        }
    }

    /// Determine MIME type from file URL.
    private func mimeType(for url: URL) -> String? {
        let ext = url.pathExtension.lowercased()
        let mimeTypes: [String: String] = [
            "pdf": "application/pdf",
            "doc": "application/msword",
            "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "xls": "application/vnd.ms-excel",
            "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "ppt": "application/vnd.ms-powerpoint",
            "pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            "txt": "text/plain",
            "csv": "text/csv",
            "png": "image/png",
            "jpg": "image/jpeg",
            "jpeg": "image/jpeg",
            "gif": "image/gif",
            "svg": "image/svg+xml",
            "zip": "application/zip",
            "mp4": "video/mp4",
            "mp3": "audio/mpeg",
        ]
        return mimeTypes[ext] ?? "application/octet-stream"
    }

    // MARK: - Rename

    /// Rename a file or folder. Updates the local list optimistically and reverts on failure.
    func renameFile(_ uniqueId: String, to newName: String) async throws {
        guard let index = files.firstIndex(where: { $0.uniqueId == uniqueId }) else { return }
        let file = files[index]
        let oldName = file.name

        // Optimistic update
        file.name = newName
        sortFiles()

        do {
            _ = try await fileService.renameItem(driveId: file.driveId, itemId: file.itemId, newName: newName)
            invalidateCache(for: currentCacheKey)
        } catch {
            // Revert on failure
            file.name = oldName
            sortFiles()
            throw error
        }
    }

    // MARK: - Drag-and-Drop

    /// Optimistic removal — called before the API move call.
    func optimisticallyRemoveFile(_ uniqueId: String) {
        files.removeAll { $0.uniqueId == uniqueId }
    }

    /// Rollback if the API move fails — re-inserts the file and re-sorts.
    func rollbackRemoveFile(_ file: UnifiedFile) {
        files.append(file)
        sortFiles()
    }

    /// Move a file into a folder via Graph API.
    /// Throws if the file and folder are on different drives (cross-drive moves are not supported).
    func moveFileToFolder(file: UnifiedFile, folder: UnifiedFile) async throws {
        guard file.driveId == folder.driveId else {
            throw MoveError.crossDriveNotSupported
        }
        _ = try await fileService.moveItem(
            driveId: file.driveId,
            itemId: file.itemId,
            toFolderId: folder.itemId
        )
        invalidateCache(for: currentCacheKey)
        invalidateCache(for: "folder_\(folder.driveId)_\(folder.itemId)")
    }

    /// Move a file to a breadcrumb folder by IDs.
    func moveFileToBreadcrumbFolder(fileId: String, driveId: String, folderId: String) async throws {
        guard let file = files.first(where: { $0.uniqueId == fileId }) else { return }
        optimisticallyRemoveFile(fileId)
        do {
            _ = try await fileService.moveItem(driveId: file.driveId, itemId: file.itemId, toFolderId: folderId)
            invalidateCache(for: currentCacheKey)
            invalidateCache(for: "folder_\(driveId)_\(folderId)")
        } catch {
            rollbackRemoveFile(file)
            throw error
        }
    }

    /// Download a file to a temporary location with authentication.
    func downloadFile(driveId: String, itemId: String) async throws -> URL {
        try await fileService.downloadFile(driveId: driveId, itemId: itemId)
    }

    private func invalidateCache(for key: String?) {
        guard let key else { return }
        memoryCache.removeValue(forKey: key)
    }

    // MARK: - Reordering

    func reorderFile(draggedId: String, targetId: String) {
        guard draggedId != targetId,
              let fromIndex = files.firstIndex(where: { $0.uniqueId == draggedId }),
              let toIndex = files.firstIndex(where: { $0.uniqueId == targetId }) else { return }

        let item = files.remove(at: fromIndex)
        files.insert(item, at: toIndex)
        saveCustomOrder()
    }

    func resetSortOrder() {
        guard let key = currentCacheKey, let context = modelContext else { return }
        let descriptor = FetchDescriptor<CustomSortOrder>(predicate: #Predicate { $0.folderKey == key })
        if let existing = (try? context.fetch(descriptor))?.first {
            context.delete(existing)
            try? context.save()
        }
        // Re-apply default sort
        files.sort { a, b in
            if a.isFolder != b.isFolder { return a.isFolder }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    private func saveCustomOrder() {
        guard let key = currentCacheKey, let context = modelContext else { return }
        let orderedIds = files.map(\.uniqueId)

        let descriptor = FetchDescriptor<CustomSortOrder>(predicate: #Predicate { $0.folderKey == key })
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.orderedIds = orderedIds
            existing.updatedAt = .now
        } else {
            context.insert(CustomSortOrder(folderKey: key, orderedIds: orderedIds))
        }
        try? context.save()
    }

    /// Clear all in-memory cached data (e.g., on sign-out).
    func clearCache() {
        memoryCache.removeAll()
        files = []
        breadcrumbs = []
        currentCacheKey = nil
        errorMessage = nil
    }
}

enum MoveError: LocalizedError {
    case crossDriveNotSupported

    var errorDescription: String? {
        switch self {
        case .crossDriveNotSupported:
            "Cannot move files between different drives (e.g., OneDrive to SharePoint). Use copy instead."
        }
    }
}
