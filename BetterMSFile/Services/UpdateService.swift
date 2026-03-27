import Foundation

// MARK: - GitHub Release Response

private struct GitHubRelease: Codable {
    let tagName: String
    let htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
    }
}

// MARK: - Update Service

@MainActor @Observable
final class UpdateService {
    private(set) var updateAvailable = false
    private(set) var latestVersion: String?
    private(set) var downloadURL: URL?
    private(set) var lastCheckDate: Date?
    private var isChecking = false

    private static let endpoint = URL(
        string: "https://api.github.com/repos/YannickAaron/BetterMSFile/releases/latest"
    )!

    private static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    // MARK: - Public

    /// Checks GitHub Releases for a newer version.
    /// Silently does nothing on failure. Debounces to at most once per hour.
    func checkForUpdate() async {
        // Prevent concurrent calls (e.g. restoreSession + didBecomeActive firing simultaneously on launch)
        guard !isChecking else { return }
        // Debounce: skip if checked less than 1 hour ago
        if let last = lastCheckDate, Date().timeIntervalSince(last) < 3600 { return }

        isChecking = true
        defer { isChecking = false }

        do {
            var request = URLRequest(url: Self.endpoint)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("BetterMSFile/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                print("[UpdateService] Non-200 response: HTTP \(code)")
                return
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let remoteVersion = release.tagName.hasPrefix("v")
                ? String(release.tagName.dropFirst())
                : release.tagName

            lastCheckDate = Date()

            if Self.isNewer(remote: remoteVersion, local: Self.currentVersion) {
                latestVersion = remoteVersion
                downloadURL = URL(string: release.htmlUrl)
                updateAvailable = true
                print("[UpdateService] Update available: \(remoteVersion) (current: \(Self.currentVersion))")
            } else {
                updateAvailable = false
                latestVersion = nil
                downloadURL = nil
            }
        } catch {
            print("[UpdateService] Check failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Version Comparison

    /// Returns `true` if `remote` is a newer semantic version than `local`.
    /// Handles versions with different component counts (e.g., 1.2 vs 1.2.1).
    static func isNewer(remote: String, local: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let localParts = local.split(separator: ".").compactMap { Int($0) }
        let maxCount = max(remoteParts.count, localParts.count)

        for i in 0..<maxCount {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r > l { return true }
            if r < l { return false }
        }
        return false // equal
    }
}
