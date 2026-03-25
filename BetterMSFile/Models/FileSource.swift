import Foundation

nonisolated enum FileSource: Codable, Hashable, Sendable {
    case oneDrive
    case sharePoint(siteName: String, siteId: String)
    case shared

    var displayName: String {
        switch self {
        case .oneDrive: "OneDrive"
        case .sharePoint(let siteName, _): siteName
        case .shared: "Shared with Me"
        }
    }

    var icon: String {
        switch self {
        case .oneDrive: "externaldrive"
        case .sharePoint: "building.2"
        case .shared: "person.2"
        }
    }
}
