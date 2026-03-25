import Foundation

enum GraphEndpoints {
    private static let baseURL = "https://graph.microsoft.com/v1.0"

    // MARK: - User

    static var me: URL { url("/me") }

    // MARK: - OneDrive

    /// Standard fields for drive item queries — ensures parentReference.path is always populated
    private static let driveItemSelect: [URLQueryItem] = [
        URLQueryItem(name: "$select", value: "id,name,size,webUrl,webDavUrl,file,folder,parentReference,lastModifiedBy,lastModifiedDateTime,createdDateTime"),
        URLQueryItem(name: "$expand", value: "thumbnails")
    ]

    static var myDrive: URL { url("/me/drive") }
    static var myDriveRoot: URL { url("/me/drive/root/children", queryItems: driveItemSelect) }
    static var sharedWithMe: URL { url("/me/drive/sharedWithMe") }
    static var recentFiles: URL { url("/me/drive/recent") }

    static func driveItemChildren(driveId: String, itemId: String) -> URL {
        url("/drives/\(driveId)/items/\(itemId)/children", queryItems: driveItemSelect)
    }

    static func driveRootChildren(driveId: String) -> URL {
        url("/drives/\(driveId)/root/children", queryItems: driveItemSelect)
    }

    static func driveItem(driveId: String, itemId: String) -> URL {
        url("/drives/\(driveId)/items/\(itemId)", queryItems: driveItemSelect)
    }

    static func driveItemContent(driveId: String, itemId: String) -> URL {
        url("/drives/\(driveId)/items/\(itemId)/content")
    }

    static func driveItemThumbnails(driveId: String, itemId: String) -> URL {
        url("/drives/\(driveId)/items/\(itemId)/thumbnails")
    }

    // MARK: - SharePoint

    static var followedSites: URL { url("/me/followedSites") }

    static func allSites(query: String = "*") -> URL {
        url("/sites", queryItems: [URLQueryItem(name: "search", value: query)])
    }

    static func siteDrives(siteId: String) -> URL {
        url("/sites/\(siteId)/drives")
    }

    // MARK: - Teams

    static var joinedTeams: URL { url("/me/joinedTeams") }

    static func groupDrives(groupId: String) -> URL {
        url("/groups/\(groupId)/drive")
    }

    static func groupSiteRoot(groupId: String) -> URL {
        url("/groups/\(groupId)/sites/root")
    }

    static func teamChannels(teamId: String) -> URL {
        url("/teams/\(teamId)/channels")
    }

    static func channelFilesFolder(teamId: String, channelId: String) -> URL {
        url("/teams/\(teamId)/channels/\(channelId)/filesFolder")
    }

    // MARK: - Search

    static var search: URL { url("/search/query") }

    // MARK: - Private

    private static func url(_ path: String, queryItems: [URLQueryItem]? = nil) -> URL {
        var components = URLComponents(string: baseURL + path)!
        components.queryItems = queryItems
        return components.url!
    }
}
