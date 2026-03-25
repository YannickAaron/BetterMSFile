import Foundation

final class FileService {
    private let client: GraphClient

    init(client: GraphClient) {
        self.client = client
    }

    /// Fetch the user's OneDrive drive metadata.
    func fetchMyDrive() async throws -> GraphDrive {
        try await client.getSingle(GraphEndpoints.myDrive)
    }

    /// Fetch children of the user's OneDrive root.
    func fetchMyDriveRoot() async throws -> [UnifiedFile] {
        let items: [GraphDriveItem] = try await client.getAllPages(GraphEndpoints.myDriveRoot)
        return items.map { $0.toUnifiedFile(source: .oneDrive) }
    }

    /// Fetch children of a specific folder.
    func fetchFolderContents(driveId: String, itemId: String) async throws -> [UnifiedFile] {
        let url = GraphEndpoints.driveItemChildren(driveId: driveId, itemId: itemId)
        let items: [GraphDriveItem] = try await client.getAllPages(url)
        return items.map { $0.toUnifiedFile(source: .oneDrive) }
    }

    /// Fetch children of a specific folder with a known source.
    func fetchFolderContents(driveId: String, itemId: String, source: FileSource) async throws -> [UnifiedFile] {
        let url = GraphEndpoints.driveItemChildren(driveId: driveId, itemId: itemId)
        let items: [GraphDriveItem] = try await client.getAllPages(url)
        return items.map { $0.toUnifiedFile(source: source) }
    }

    /// Fetch root of a specific drive (e.g., SharePoint document library).
    func fetchDriveRoot(driveId: String, source: FileSource) async throws -> [UnifiedFile] {
        let url = GraphEndpoints.driveRootChildren(driveId: driveId)
        let items: [GraphDriveItem] = try await client.getAllPages(url)
        return items.map { $0.toUnifiedFile(source: source) }
    }

    /// Fetch files shared with the user.
    func fetchSharedWithMe() async throws -> [UnifiedFile] {
        let items: [GraphDriveItem] = try await client.getAllPages(GraphEndpoints.sharedWithMe)
        return items.map { $0.toUnifiedFile(source: .shared) }
    }

    /// Fetch recently accessed files.
    func fetchRecentFiles() async throws -> [UnifiedFile] {
        let items: [GraphDriveItem] = try await client.getAllPages(GraphEndpoints.recentFiles)
        return items.map { $0.toUnifiedFile(source: .oneDrive) }
    }

    /// Fetch metadata for a single drive item.
    func fetchItem(driveId: String, itemId: String) async throws -> GraphDriveItem {
        try await client.getSingle(GraphEndpoints.driveItem(driveId: driveId, itemId: itemId))
    }

    /// Get the download URL for a file (follows 302 redirect).
    func getDownloadURL(driveId: String, itemId: String) -> URL {
        GraphEndpoints.driveItemContent(driveId: driveId, itemId: itemId)
    }
}

// MARK: - Mapping

extension GraphDriveItem {
    func toUnifiedFile(source: FileSource) -> UnifiedFile {
        let driveId = parentReference?.driveId ?? ""
        let itemId = remoteItem?.id ?? id

        return UnifiedFile(
            itemId: itemId,
            driveId: driveId,
            name: name,
            mimeType: mimeType ?? remoteItem?.file?.mimeType,
            size: size ?? remoteItem?.size ?? 0,
            isFolder: isFolder || remoteItem?.folder != nil,
            modifiedAt: parseDate(lastModifiedDateTime) ?? .now,
            createdAt: parseDate(createdDateTime) ?? .now,
            modifiedBy: lastModifiedBy?.user?.displayName,
            webURL: webUrl ?? remoteItem?.webUrl ?? "",
            parentPath: parentReference?.path ?? "",
            source: source,
            siteId: parentReference?.siteId,
            thumbnailURL: thumbnails?.first?.medium?.url,
            webDavURL: webDavUrl ?? remoteItem?.webDavUrl
        )
    }

    private func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        return ISO8601DateFormatter().date(from: string)
    }
}
