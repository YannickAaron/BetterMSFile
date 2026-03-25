import Foundation

final class GraphClient {
    private let authService: AuthService
    private let session = URLSession.shared
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

        while let currentURL = nextURL {
            let collection: GraphCollection<T> = try await get(currentURL)
            allItems.append(contentsOf: collection.value)

            if let nextLink = collection.nextLink {
                nextURL = URL(string: nextLink)
            } else {
                nextURL = nil
            }
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
        case 429:
            // Throttled — respect Retry-After header
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap(Double.init) ?? pow(2.0, Double(retryCount))
            let delay = min(retryAfter, 60) // Cap at 60 seconds

            if retryCount < 3 {
                try await Task.sleep(for: .seconds(delay))
                return try await performRequest(request: request, retryCount: retryCount + 1)
            } else {
                throw GraphError.throttled
            }
        case 401:
            throw GraphError.unauthorized
        case 404:
            throw GraphError.notFound
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
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
    case httpError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid response from Microsoft Graph"
        case .throttled: "Too many requests. Please wait and try again."
        case .unauthorized: "Authentication expired. Please sign in again."
        case .notFound: "Resource not found."
        case .httpError(let code, let message): "HTTP \(code): \(message)"
        }
    }
}
