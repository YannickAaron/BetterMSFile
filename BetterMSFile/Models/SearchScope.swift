import Foundation

enum SearchScope: Hashable {
    case all
    case myOneDrive
    case site(id: String, name: String)

    var displayName: String {
        switch self {
        case .all: "All Files"
        case .myOneDrive: "My OneDrive"
        case .site(_, let name): name
        }
    }
}
