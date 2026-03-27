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

    /// Download a file to a temporary location with proper authentication.
    func downloadFile(driveId: String, itemId: String) async throws -> URL {
        let url = GraphEndpoints.driveItemContent(driveId: driveId, itemId: itemId)
        return try await client.downloadFile(url)
    }

    /// Create a new folder inside a parent folder (or drive root if parentId is "root").
    func createFolder(driveId: String, parentId: String, name: String) async throws -> GraphDriveItem {
        let url = GraphEndpoints.driveItemChildren(driveId: driveId, itemId: parentId)
        let body = CreateFolderRequest(name: name, folder: .init(), conflictBehavior: "rename")
        return try await client.post(url, body: body)
    }

    /// Delete a file or folder from a drive.
    func deleteItem(driveId: String, itemId: String) async throws {
        let url = GraphEndpoints.deleteDriveItem(driveId: driveId, itemId: itemId)
        try await client.delete(url)
    }

    /// Move a file to a different folder via PATCH.
    func moveItem(driveId: String, itemId: String, toFolderId: String) async throws -> GraphDriveItem {
        let url = GraphEndpoints.driveItem(driveId: driveId, itemId: itemId)
        let body = MoveItemRequest(parentReference: .init(id: toFolderId))
        return try await client.patch(url, body: body)
    }
    // MARK: - Upload

    /// Simple upload for files under 4MB.
    func uploadSmall(
        data: Data,
        filename: String,
        driveId: String,
        parentId: String,
        contentType: String,
        conflictBehavior: String = "rename"
    ) async throws -> GraphDriveItem {
        let url = GraphEndpoints.uploadSmall(
            driveId: driveId,
            parentId: parentId,
            filename: filename,
            conflictBehavior: conflictBehavior
        )
        let responseData = try await client.put(url, data: data, contentType: contentType)
        return try JSONDecoder().decode(GraphDriveItem.self, from: responseData)
    }

    /// Create a resumable upload session for large files.
    func createUploadSession(
        driveId: String,
        parentId: String,
        filename: String,
        conflictBehavior: String = "rename"
    ) async throws -> UploadSession {
        let url = GraphEndpoints.createUploadSession(driveId: driveId, parentId: parentId, filename: filename)
        let body = CreateUploadSessionRequest(
            item: .init(conflictBehavior: conflictBehavior, name: filename)
        )
        let responseData = try await client.postRaw(url, body: body)
        return try JSONDecoder().decode(UploadSession.self, from: responseData)
    }

    /// Upload a chunk to a resumable upload session.
    func uploadChunk(
        sessionURL: URL,
        data: Data,
        range: String,
        totalSize: Int64
    ) async throws -> Data {
        let contentRange = "bytes \(range)/\(totalSize)"
        return try await client.putUnauthenticated(
            sessionURL,
            data: data,
            contentType: "application/octet-stream",
            contentRange: contentRange
        )
    }

    /// Rename a file or folder via PATCH.
    func renameItem(driveId: String, itemId: String, newName: String) async throws -> GraphDriveItem {
        let url = GraphEndpoints.driveItem(driveId: driveId, itemId: itemId)
        let body = RenameItemRequest(name: newName)
        return try await client.patch(url, body: body)
    }
}

// MARK: - Rename Request

private struct RenameItemRequest: Encodable {
    let name: String
}

// MARK: - Upload Request

private struct CreateUploadSessionRequest: Encodable {
    let item: UploadItemProperties

    struct UploadItemProperties: Encodable {
        let conflictBehavior: String
        let name: String

        enum CodingKeys: String, CodingKey {
            case conflictBehavior = "@microsoft.graph.conflictBehavior"
            case name
        }
    }
}

struct UploadSession: Codable {
    let uploadUrl: String
    let expirationDateTime: String?
}

// MARK: - Create Folder Request

private struct CreateFolderRequest: Encodable {
    let name: String
    let folder: FolderFacet
    let conflictBehavior: String

    enum CodingKeys: String, CodingKey {
        case name, folder
        case conflictBehavior = "@microsoft.graph.conflictBehavior"
    }

    struct FolderFacet: Encodable {}
}

// MARK: - Move Request

private struct MoveItemRequest: Encodable {
    let parentReference: ParentRef
    struct ParentRef: Encodable {
        let id: String
    }
}

// MARK: - Mapping

private let iso8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

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
            largeThumbnailURL: thumbnails?.first?.large?.url,
            webDavURL: webDavUrl ?? remoteItem?.webDavUrl
        )
    }

    private func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        return iso8601Formatter.date(from: string)
    }
}
