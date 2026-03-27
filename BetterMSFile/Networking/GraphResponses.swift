import Foundation

// MARK: - Paginated Collection

struct GraphCollection<T: Codable>: Codable {
    let value: [T]
    let nextLink: String?

    enum CodingKeys: String, CodingKey {
        case value
        case nextLink = "@odata.nextLink"
    }
}

// MARK: - Drive Item (OneDrive / SharePoint file or folder)

struct GraphDriveItem: Codable {
    let id: String
    let name: String
    let size: Int64?
    let webUrl: String?
    let webDavUrl: String?  // Direct WebDAV URL — the reliable path for opening in Office apps
    let createdDateTime: String?
    let lastModifiedDateTime: String?
    let file: GraphFileInfo?
    let folder: GraphFolderInfo?
    let parentReference: GraphParentReference?
    let lastModifiedBy: GraphIdentitySet?
    let remoteItem: GraphRemoteItem?
    let thumbnails: [GraphThumbnailSet]?

    var isFolder: Bool { folder != nil }
    var mimeType: String? { file?.mimeType }
}

struct GraphFileInfo: Codable {
    let mimeType: String?
}

struct GraphFolderInfo: Codable {
    let childCount: Int?
}

struct GraphParentReference: Codable {
    let driveId: String?
    let id: String?
    let path: String?
    let siteId: String?
}

struct GraphIdentitySet: Codable {
    let user: GraphIdentity?
}

struct GraphIdentity: Codable {
    let displayName: String?
    let id: String?
}

struct GraphRemoteItem: Codable {
    let id: String?
    let name: String?
    let webUrl: String?
    let webDavUrl: String?
    let parentReference: GraphParentReference?
    let file: GraphFileInfo?
    let folder: GraphFolderInfo?
    let size: Int64?
}

// MARK: - Thumbnails

struct GraphThumbnailSet: Codable {
    let small: GraphThumbnail?
    let medium: GraphThumbnail?
    let large: GraphThumbnail?
}

struct GraphThumbnail: Codable {
    let url: String?
    let width: Int?
    let height: Int?
}

// MARK: - Versions

struct GraphDriveItemVersion: Codable {
    let id: String
    let lastModifiedDateTime: String?
    let size: Int64?
    let lastModifiedBy: GraphIdentitySet?
}

// MARK: - SharePoint Site

struct GraphSite: Codable {
    let id: String
    let displayName: String?
    let name: String?
    let webUrl: String?
}

// MARK: - Drive

struct GraphDrive: Codable {
    let id: String
    let name: String?
    let driveType: String?
    let webUrl: String?
}

// MARK: - Teams

struct GraphTeam: Codable {
    let id: String
    let displayName: String?
    let description: String?
}

struct GraphChannel: Codable {
    let id: String
    let displayName: String?
    let membershipType: String?   // "standard", "private", "shared"
}

/// Response from /teams/{id}/channels/{id}/filesFolder
struct GraphChannelFilesFolder: Codable {
    let id: String
    let name: String?
    let parentReference: GraphParentReference?
}
