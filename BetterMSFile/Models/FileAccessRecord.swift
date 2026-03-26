import Foundation
import SwiftData

@Model
final class FileAccessRecord {
    @Attribute(.unique) var uniqueId: String
    var itemId: String
    var driveId: String
    var name: String
    var isFolder: Bool
    var source: FileSource
    var siteId: String?
    var mimeType: String?
    var webURL: String
    var accessCount: Int
    var lastAccessedAt: Date
    var firstAccessedAt: Date

    init(from file: UnifiedFile) {
        self.uniqueId = file.uniqueId
        self.itemId = file.itemId
        self.driveId = file.driveId
        self.name = file.name
        self.isFolder = file.isFolder
        self.source = file.source
        self.siteId = file.siteId
        self.mimeType = file.mimeType
        self.webURL = file.webURL
        self.accessCount = 1
        self.lastAccessedAt = .now
        self.firstAccessedAt = .now
    }

    /// Convert back to a lightweight UnifiedFile for navigation.
    func toUnifiedFile() -> UnifiedFile {
        UnifiedFile(
            itemId: itemId,
            driveId: driveId,
            name: name,
            mimeType: mimeType,
            isFolder: isFolder,
            webURL: webURL,
            source: source,
            siteId: siteId
        )
    }
}
