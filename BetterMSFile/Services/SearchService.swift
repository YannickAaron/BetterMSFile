import Foundation

final class SearchService {
    private let client: GraphClient

    init(client: GraphClient) {
        self.client = client
    }

    func search(query: String, filters: SearchFilters = SearchFilters()) async throws -> [UnifiedFile] {
        let request = buildSearchRequest(query: query, filters: filters)
        let response: SearchResponse = try await client.post(GraphEndpoints.search, body: request)

        var results: [UnifiedFile] = []
        for resultSet in response.value {
            for hit in resultSet.hitsContainers ?? [] {
                for item in hit.hits ?? [] {
                    if let file = item.toUnifiedFile() {
                        results.append(file)
                    }
                }
            }
        }
        return results
    }

    private func buildSearchRequest(query: String, filters: SearchFilters) -> SearchRequest {
        var queryString = query

        // Add file type filter
        if let fileType = filters.fileType {
            queryString += " filetype:\(fileType)"
        }

        // Add author filter
        if let author = filters.author {
            queryString += " author:\"\(author)\""
        }

        var queryFilter: String?
        if let modifiedAfter = filters.modifiedAfter {
            let formatter = ISO8601DateFormatter()
            queryFilter = "lastModifiedDateTime >= '\(formatter.string(from: modifiedAfter))'"
        }

        return SearchRequest(
            requests: [
                SearchRequestItem(
                    entityTypes: ["driveItem"],
                    query: SearchQueryString(queryString: queryString),
                    from: 0,
                    size: 50,
                    queryAlterationOptions: nil,
                    fields: nil
                )
            ]
        )
    }
}

// MARK: - Search Filters

struct SearchFilters {
    var fileType: String?       // e.g., "docx", "pdf", "xlsx"
    var modifiedAfter: Date?
    var author: String?
}

// MARK: - Search Request Models

struct SearchRequest: Encodable {
    let requests: [SearchRequestItem]
}

struct SearchRequestItem: Encodable {
    let entityTypes: [String]
    let query: SearchQueryString
    let from: Int
    let size: Int
    let queryAlterationOptions: String?
    let fields: [String]?
}

struct SearchQueryString: Encodable {
    let queryString: String
}

// MARK: - Search Response Models

struct SearchResponse: Codable {
    let value: [SearchResultSet]
}

struct SearchResultSet: Codable {
    let hitsContainers: [SearchHitsContainer]?
}

struct SearchHitsContainer: Codable {
    let hits: [SearchHit]?
    let total: Int?
    let moreResultsAvailable: Bool?
}

struct SearchHit: Codable {
    let hitId: String?
    let resource: SearchResource?
}

struct SearchResource: Codable {
    let id: String?
    let name: String?
    let size: Int64?
    let webUrl: String?
    let createdDateTime: String?
    let lastModifiedDateTime: String?
    let parentReference: SearchParentReference?
    let file: SearchFileInfo?
    let folder: SearchFolderInfo?
    let lastModifiedBy: SearchIdentitySet?

    // Additional fields from search
    struct SearchFileInfo: Codable {
        let mimeType: String?
    }

    struct SearchFolderInfo: Codable {
        let childCount: Int?
    }

    struct SearchParentReference: Codable {
        let driveId: String?
        let siteId: String?
    }

    struct SearchIdentitySet: Codable {
        let user: SearchIdentity?
    }

    struct SearchIdentity: Codable {
        let displayName: String?
    }
}

extension SearchHit {
    func toUnifiedFile() -> UnifiedFile? {
        guard let resource, let id = resource.id ?? hitId else { return nil }
        let driveId = resource.parentReference?.driveId ?? ""

        let source: FileSource
        if resource.parentReference?.siteId != nil {
            source = .sharePoint(siteName: "SharePoint", siteId: resource.parentReference?.siteId ?? "")
        } else {
            source = .oneDrive
        }

        let formatter = ISO8601DateFormatter()

        return UnifiedFile(
            itemId: id,
            driveId: driveId,
            name: resource.name ?? "Unknown",
            mimeType: resource.file?.mimeType,
            size: resource.size ?? 0,
            isFolder: resource.folder != nil,
            modifiedAt: resource.lastModifiedDateTime.flatMap { formatter.date(from: $0) } ?? .now,
            createdAt: resource.createdDateTime.flatMap { formatter.date(from: $0) } ?? .now,
            modifiedBy: resource.lastModifiedBy?.user?.displayName,
            webURL: resource.webUrl ?? "",
            parentPath: "",
            source: source,
            siteId: resource.parentReference?.siteId
        )
    }
}
