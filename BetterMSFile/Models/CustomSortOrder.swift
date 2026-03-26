import Foundation
import SwiftData

@Model
final class CustomSortOrder {
    @Attribute(.unique) var folderKey: String
    var orderedIds: [String]
    var updatedAt: Date

    init(folderKey: String, orderedIds: [String]) {
        self.folderKey = folderKey
        self.orderedIds = orderedIds
        self.updatedAt = .now
    }
}
