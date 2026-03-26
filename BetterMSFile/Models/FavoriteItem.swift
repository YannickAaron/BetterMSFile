import Foundation
import SwiftData

@Model
final class FavoriteItem {
    @Attribute(.unique) var uniqueId: String
    var itemId: String
    var driveId: String
    var name: String
    var isFolder: Bool
    var source: FileSource
    var siteId: String?
    var addedAt: Date

    init(from file: UnifiedFile) {
        self.uniqueId = file.uniqueId
        self.itemId = file.itemId
        self.driveId = file.driveId
        self.name = file.name
        self.isFolder = file.isFolder
        self.source = file.source
        self.siteId = file.siteId
        self.addedAt = .now
    }

    /// Convert back to a lightweight UnifiedFile for navigation.
    func toUnifiedFile() -> UnifiedFile {
        UnifiedFile(
            itemId: itemId,
            driveId: driveId,
            name: name,
            isFolder: isFolder,
            source: source,
            siteId: siteId
        )
    }
}
