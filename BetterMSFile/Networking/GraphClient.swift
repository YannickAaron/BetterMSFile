import Foundation

final class GraphClient {
    private let authService: AuthService
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init(authService: AuthService) {
        self.authService = authService
    }

    // MARK: - GET with automatic pagination

    func get<T: Codable>(_ url: URL) async throws -> GraphCollection<T> {
        let data = try await performRequest(url: url)
        return try decoder.decode(GraphCollection<T>.self, from: data)
    }

    /// Fetch a single object (e.g., /me).
    func getSingle<T: Codable>(_ url: URL) async throws -> T {
        let data = try await performRequest(url: url)
        return try decoder.decode(T.self, from: data)
    }

    /// Fetch all pages of a paginated endpoint.
    func getAllPages<T: Codable>(_ url: URL) async throws -> [T] {
        var allItems: [T] = []
        var nextURL: URL? = url
        var pageCount = 0
        let maxPages = 100

        while let currentURL = nextURL, pageCount < maxPages {
            pageCount += 1
            let collection: GraphCollection<T> = try await get(currentURL)
            allItems.append(contentsOf: collection.value)
            nextURL = collection.nextLink.flatMap { URL(string: $0) }
        }

        return allItems
    }

    /// POST with JSON body (used for search).
    func post<Body: Encodable, Response: Codable>(_ url: URL, body: Body) async throws -> Response {
        var request = try await authenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let data = try await performRequest(request: request)
        return try decoder.decode(Response.self, from: data)
    }

    /// PATCH with JSON body (used for moving/updating items).
    func patch<Body: Encodable, Response: Codable>(_ url: URL, body: Body) async throws -> Response {
        var request = try await authenticatedRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let data = try await performRequest(request: request)
        return try decoder.decode(Response.self, from: data)
    }

    /// DELETE with no response body (returns 204 No Content).
    func delete(_ url: URL) async throws {
        var request = try await authenticatedRequest(url: url)
        request.httpMethod = "DELETE"
        _ = try await performRequest(request: request)
    }

    /// Get raw data (used for file downloads).
    func getData(_ url: URL) async throws -> Data {
        try await performRequest(url: url)
    }

    // MARK: - Private

    private func performRequest(url: URL) async throws -> Data {
        let request = try await authenticatedRequest(url: url)
        return try await performRequest(request: request)
    }

    private func performRequest(request: URLRequest, retryCount: Int = 0) async throws -> Data {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GraphError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data

        case 401:
            // Token expired — silently refresh and retry once
            if retryCount < 1 {
                print("GraphClient: 401 — refreshing token and retrying")
                let freshRequest = try await authenticatedRequest(url: request.url!)
                return try await performRequest(request: freshRequest, retryCount: retryCount + 1)
            }
            throw GraphError.unauthorized

        case 429:
            // Throttled — respect Retry-After header with exponential backoff
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap(Double.init) ?? pow(2.0, Double(retryCount))
            let delay = min(retryAfter, 60)

            if retryCount < 3 {
                print("GraphClient: 429 — throttled, retrying after \(delay)s")
                try await Task.sleep(for: .seconds(delay))
                return try await performRequest(request: request, retryCount: retryCount + 1)
            }
            throw GraphError.throttled

        case 502, 503, 504:
            // Server error / timeout — retry once after short delay
            if retryCount < 1 {
                print("GraphClient: \(httpResponse.statusCode) — server error, retrying after 2s")
                try await Task.sleep(for: .seconds(2))
                return try await performRequest(request: request, retryCount: retryCount + 1)
            }
            throw GraphError.serverError(httpResponse.statusCode)

        case 404:
            throw GraphError.notFound

        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("GraphClient: HTTP \(httpResponse.statusCode) — \(request.url?.path ?? "unknown") — \(message)")
            throw GraphError.httpError(statusCode: httpResponse.statusCode, message: message)
        }
    }

    private func authenticatedRequest(url: URL) async throws -> URLRequest {
        let token = try await authService.getAccessToken()
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}

enum GraphError: LocalizedError {
    case invalidResponse
    case throttled
    case unauthorized
    case notFound
    case serverError(Int)
    case httpError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid response from Microsoft Graph."
        case .throttled: "Too many requests. Please wait and try again."
        case .unauthorized: "Session expired. Please sign in again."
        case .notFound: "Resource not found."
        case .serverError(504): "Search timed out — try a more specific query."
        case .serverError(let code): "Microsoft servers temporarily unavailable (\(code))."
        case .httpError(let code, _): "Request failed (\(code)). Please try again."
        }
    }
}
