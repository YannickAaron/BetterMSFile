import Foundation
import SwiftData

@Model
final class UnifiedFile {
    @Attribute(.unique) var uniqueId: String
    var itemId: String
    var driveId: String
    var name: String
    var mimeType: String?
    var size: Int64
    var isFolder: Bool
    var modifiedAt: Date
    var createdAt: Date
    var modifiedBy: String?
    var webURL: String
    var parentPath: String
    var source: FileSource
    var siteId: String?
    var thumbnailURL: String?
    var lastCachedAt: Date

    init(
        itemId: String,
        driveId: String,
        name: String,
        mimeType: String? = nil,
        size: Int64 = 0,
        isFolder: Bool = false,
        modifiedAt: Date = .now,
        createdAt: Date = .now,
        modifiedBy: String? = nil,
        webURL: String = "",
        parentPath: String = "",
        source: FileSource = .oneDrive,
        siteId: String? = nil,
        thumbnailURL: String? = nil
    ) {
        self.uniqueId = "\(driveId)_\(itemId)"
        self.itemId = itemId
        self.driveId = driveId
        self.name = name
        self.mimeType = mimeType
        self.size = size
        self.isFolder = isFolder
        self.modifiedAt = modifiedAt
        self.createdAt = createdAt
        self.modifiedBy = modifiedBy
        self.webURL = webURL
        self.parentPath = parentPath
        self.source = source
        self.siteId = siteId
        self.thumbnailURL = thumbnailURL
        self.lastCachedAt = .now
    }
}
