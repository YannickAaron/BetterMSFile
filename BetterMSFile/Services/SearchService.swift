import Foundation

final class SearchService {
    private let client: GraphClient

    init(client: GraphClient) {
        self.client = client
    }

    struct SearchResult {
        let files: [UnifiedFile]
        let moreAvailable: Bool
        let total: Int?
    }

    func search(query: String, filters: SearchFilters = SearchFilters(), scope: SearchScope = .all, from: Int = 0) async throws -> SearchResult {
        let request = buildSearchRequest(query: query, filters: filters, from: from, scope: scope)
        let response: SearchResponse = try await client.post(GraphEndpoints.search, body: request)

        var files: [UnifiedFile] = []
        var moreAvailable = false
        var total: Int?

        for resultSet in response.value {
            for container in resultSet.hitsContainers ?? [] {
                for item in container.hits ?? [] {
                    if let file = item.toUnifiedFile() {
                        files.append(file)
                    }
                }
                if container.moreResultsAvailable == true {
                    moreAvailable = true
                }
                if let containerTotal = container.total {
                    total = containerTotal
                }
            }
        }

        // Client-side filtering for OneDrive scope (Graph API doesn't support this natively)
        if case .myOneDrive = scope {
            let filtered = files.filter {
                if case .oneDrive = $0.source { return true }
                if case .shared = $0.source { return true }
                return false
            }
            // Adjust total and moreAvailable to reflect filtered results.
            // If we filtered out items, there may be more OneDrive results in subsequent pages.
            let adjustedMoreAvailable = moreAvailable || (filtered.count < files.count && files.count > 0)
            return SearchResult(files: filtered, moreAvailable: adjustedMoreAvailable, total: nil)
        }

        return SearchResult(files: files, moreAvailable: moreAvailable, total: total)
    }

    private func buildSearchRequest(query: String, filters: SearchFilters, from: Int = 0, scope: SearchScope = .all) -> SearchRequest {
        // Escape special characters that could break KQL syntax
        var queryString = escapeKQL(query)

        // Add file type filter
        if let fileType = filters.fileType {
            queryString += " filetype:\(escapeKQL(fileType))"
        }

        // Add author filter
        if let author = filters.author {
            queryString += " author:\(escapeKQL(author))"
        }

        // Add date filter
        if let modifiedAfter = filters.modifiedAfter {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            queryString += " lastModifiedTime>=\"\(formatter.string(from: modifiedAfter))\""
        }

        // Add scope filter (SharePoint site scoping via KQL)
        if case .site(let id, _) = scope {
            queryString += " siteId:\(id)"
        }

        return SearchRequest(
            requests: [
                SearchRequestItem(
                    entityTypes: ["driveItem"],
                    query: SearchQueryString(queryString: queryString),
                    from: from,
                    size: 25,
                    queryAlterationOptions: nil,
                    fields: nil
                )
            ]
        )
    }

    /// Escape a user query for safe use in KQL (Keyword Query Language).
    /// Wraps the term in double quotes so special characters are treated as literals.
    private func escapeKQL(_ term: String) -> String {
        // Escape internal double quotes, then wrap in quotes to treat as a phrase
        let escaped = term.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
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
