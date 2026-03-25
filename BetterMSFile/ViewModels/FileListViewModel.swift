import Foundation
import SwiftData

@Observable
final class FileListViewModel {
    private let fileService: FileService
    private var modelContext: ModelContext?

    var files: [UnifiedFile] = []
    var isLoading = false
    var isRefreshing = false
    var errorMessage: String?

    /// Navigation stack for folder drill-down.
    var breadcrumbs: [BreadcrumbItem] = []

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
    func loadTeamChannels(_ channels: [TeamChannel], teamName: String, siteId: String) async {
        let source = FileSource.sharePoint(siteName: teamName, siteId: siteId)
        breadcrumbs = [BreadcrumbItem(name: teamName, driveId: "", itemId: nil, source: source)]
        errorMessage = nil
        isLoading = true

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
    }

    /// Show a SharePoint site's document libraries as navigable folders.
    func loadSiteDrives(site: SharePointSite) async {
        let siteName = site.displayName
        breadcrumbs = [BreadcrumbItem(name: siteName, driveId: "", itemId: nil, source: .sharePoint(siteName: siteName, siteId: site.id))]
        errorMessage = nil
        isLoading = true

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
    }

    /// Navigate to a file's parent folder (jump to location from search).
    func navigateToFile(_ file: UnifiedFile) async {
        guard !file.driveId.isEmpty else { return }

        let source = file.source
        // Fetch the item to get its parentReference with the parent folder ID
        do {
            let item = try await fileService.fetchItem(driveId: file.driveId, itemId: file.itemId)
            if let parentId = item.parentReference?.id, !parentId.isEmpty {
                // Load the parent folder
                breadcrumbs = [
                    BreadcrumbItem(name: source.displayName, driveId: file.driveId, itemId: nil, source: source),
                    BreadcrumbItem(name: "...", driveId: file.driveId, itemId: parentId, source: source)
                ]
                await loadWithCache(
                    cacheKey: "folder_\(file.driveId)_\(parentId)",
                    fetch: { try await self.fileService.fetchFolderContents(driveId: file.driveId, itemId: parentId, source: source) }
                )
            } else {
                // File is at drive root
                breadcrumbs = [BreadcrumbItem(name: source.displayName, driveId: file.driveId, itemId: nil, source: source)]
                await loadWithCache(
                    cacheKey: "drive_\(file.driveId)",
                    fetch: { try await self.fileService.fetchDriveRoot(driveId: file.driveId, source: source) }
                )
            }
        } catch {
            // Fallback: load the drive root
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
            saveToCache(files: freshFiles, key: cacheKey)
            files = freshFiles
            sortFiles()
        } catch {
            // Only show error if we have no cached data
            if files.isEmpty {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
        isRefreshing = false
    }

    // MARK: - Cache (in-memory + SwiftData persistence)

    private func loadFromCache(key: String) -> [UnifiedFile]? {
        guard let entry = memoryCache[key] else { return nil }
        return entry.files
    }

    private func saveToCache(files: [UnifiedFile], key: String) {
        memoryCache[key] = (files: files, cachedAt: .now)

        // Also persist to SwiftData for cross-launch cache
        guard let context = modelContext else { return }
        for file in files {
            file.lastCachedAt = .now
            context.insert(file)
        }
        try? context.save()
    }

    private func sortFiles() {
        files.sort { a, b in
            if a.isFolder != b.isFolder { return a.isFolder }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }
}
