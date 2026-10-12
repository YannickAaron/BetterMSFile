import Crypto
import Foundation
import Observation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Linux stand-in for BetterMSFile/Auth/AuthService.swift (MSAL is Apple-only).
/// Same surface, so GraphClient, MCPServer and AppState compile unchanged.
/// Sign-in is OAuth 2.0 auth code + PKCE in the browser with the same redirect URI as the Mac app
/// (`MSALConfig.redirectUri`, a custom scheme), so the Azure app registration needs no changes: this app
/// registers itself as that scheme's handler, the browser launches `bettermsfile --auth-callback <url>`,
/// and that process hands the URL to the waiting sign-in through a private runtime file.
/// The refresh token lives in the desktop keyring via `secret-tool` (libsecret); the access token only in memory.
@Observable
final class AuthService {
    /// False in the headless MCP process: a refresh failure must not open a browser sign-in.
    var allowsInteractiveSignIn = true
    private(set) var isAuthenticated = false
    private var accessToken: String?
    private var expiresAt = Date.distantPast

    private static let authority = "https://login.microsoftonline.com/\(MSALConfig.tenantId)/oauth2/v2.0"
    private static let scope = (MSALConfig.scopes + ["offline_access"]).joined(separator: " ")

    /// Try to restore a previously signed-in account silently.
    func restoreSession() async {
        guard Keyring.load() != nil else { return }
        do {
            _ = try await refresh()
        } catch {
            FileHandle.standardError.write(Data("Session restore failed: \(error.localizedDescription)\n".utf8))
        }
    }

    /// Sign in interactively in the user's browser.
    func signIn() async throws {
        let verifier = Self.randomToken()
        let state = Self.randomToken()
        let redirectURI = MSALConfig.redirectUri
        try? FileManager.default.removeItem(at: AuthCallback.file)
        AuthCallback.registerSchemeHandler()

        guard var authorize = URLComponents(string: "\(Self.authority)/authorize") else { throw AuthError.unknownError }
        authorize.queryItems = [
            URLQueryItem(name: "client_id", value: MSALConfig.clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: Self.scope),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "prompt", value: "select_account"),
        ]
        guard let url = authorize.url else { throw AuthError.unknownError }

        FileHandle.standardError.write(Data("Opening your browser to sign in. If it doesn't open, visit:\n\(url.absoluteString)\n".utf8))
        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        open.arguments = ["xdg-open", url.absoluteString]
        open.standardOutput = FileHandle.nullDevice
        open.standardError = FileHandle.nullDevice
        try? open.run()

        let query = try await AuthCallback.wait(timeout: 300)
        guard query["state"] == state else { throw LinuxAuthError("Sign-in response didn't match this request. Try again.") }
        guard let code = query["code"] else {
            throw LinuxAuthError(query["error_description"] ?? query["error"] ?? "Sign-in was cancelled.")
        }
        try await requestToken([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "code_verifier": verifier,
        ])
    }

    /// Sign out and clear the stored refresh token.
    func signOut() async throws {
        Keyring.delete()
        accessToken = nil
        expiresAt = .distantPast
        isAuthenticated = false
    }

    /// Cached access token, refreshed when it's about to expire. Call before each Graph API request.
    func getAccessToken() async throws -> String {
        if let accessToken, expiresAt > Date().addingTimeInterval(60) { return accessToken }
        do {
            return try await refresh()
        } catch {
            guard allowsInteractiveSignIn else {
                isAuthenticated = false
                accessToken = nil
                throw AuthError.notSignedIn
            }
            try await signIn()
            guard let accessToken else { throw AuthError.tokenAcquisitionFailed }
            return accessToken
        }
    }

    // MARK: - Private

    private func refresh() async throws -> String {
        guard let refreshToken = Keyring.load() else { throw AuthError.notSignedIn }
        return try await requestToken(["grant_type": "refresh_token", "refresh_token": refreshToken])
    }

    @discardableResult
    private func requestToken(_ params: [String: String]) async throws -> String {
        guard let url = URL(string: "\(Self.authority)/token") else { throw AuthError.unknownError }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let form = params.merging(["client_id": MSALConfig.clientId, "scope": Self.scope]) { a, _ in a }
        request.httpBody = Data(form.map { "\(Self.formEncode($0.key))=\(Self.formEncode($0.value))" }
            .joined(separator: "&").utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        struct TokenResponse: Decodable {
            let access_token: String?
            let refresh_token: String?
            let expires_in: Int?
            let error: String?
            let error_description: String?
        }
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)
        guard let token = response.access_token else {
            if response.error == "invalid_grant" { throw AuthError.notSignedIn }
            throw LinuxAuthError(response.error_description ?? response.error ?? "Token request failed.")
        }
        // Microsoft rotates refresh tokens; always keep the newest.
        if let refreshToken = response.refresh_token { try Keyring.save(refreshToken) }
        accessToken = token
        expiresAt = Date().addingTimeInterval(TimeInterval(response.expires_in ?? 3600))
        isAuthenticated = true
        return token
    }

    private static func randomToken() -> String {
        var generator = SystemRandomNumberGenerator()
        return base64URL(Data((0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) }))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func formEncode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")) ?? s
    }
}

enum AuthError: LocalizedError {
    case msalNotInitialized
    case notSignedIn
    case tokenAcquisitionFailed
    case unknownError

    var errorDescription: String? {
        switch self {
        case .msalNotInitialized: "Sign-in isn't configured. Check your Config.swift values."
        case .notSignedIn: "Not signed in to Microsoft 365. Sign in again in the app or with `bettermsfile --login`."
        case .tokenAcquisitionFailed: "Failed to acquire access token."
        case .unknownError: "An unknown authentication error occurred."
        }
    }
}

struct LinuxAuthError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

/// Refresh token in the desktop keyring (GNOME Keyring / KWallet) through libsecret's `secret-tool`.
/// ponytail: CLI instead of libsecret C bindings; needs the libsecret-tools package.
private enum Keyring {
    private static let attributes = ["service", "bettermsfile", "account", "microsoft365"]

    static func load() -> String? {
        guard let (status, out) = try? run(["lookup"] + attributes), status == 0 else { return nil }
        let token = String(decoding: out, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return token.isEmpty ? nil : token
    }

    static func save(_ token: String) throws {
        let result = try? run(["store", "--label=BetterMSFile (Microsoft 365)"] + attributes, input: Data(token.utf8))
        guard result?.status == 0 else {
            throw LinuxAuthError("Couldn't save the sign-in to your keyring. Install libsecret-tools and make sure a keyring (GNOME Keyring or KWallet) is running.")
        }
    }

    static func delete() {
        _ = try? run(["clear"] + attributes)
    }

    private static func run(_ args: [String], input: Data? = nil) throws -> (status: Int32, out: Data) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["secret-tool"] + args
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        let stdin = Pipe()
        process.standardInput = stdin
        try process.run()
        if let input { stdin.fileHandleForWriting.write(input) }
        try stdin.fileHandleForWriting.close()
        let out = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, out)
    }
}

/// Hand-off of the browser redirect (`msauth…://auth?code=…&state=…`) from the scheme-handler process to the
/// process waiting in `signIn()`. ponytail: polls a file in the user-private runtime dir; `state` + PKCE guard it.
enum AuthCallback {
    static var file: URL {
        let dir = ProcessInfo.processInfo.environment["XDG_RUNTIME_DIR"] ?? NSTemporaryDirectory()
        return URL(fileURLWithPath: dir).appendingPathComponent("bettermsfile-auth-callback")
    }

    private static var scheme: String { URL(string: MSALConfig.redirectUri)?.scheme?.lowercased() ?? "" }

    /// True for the redirect URL the browser passes to `bettermsfile --auth-callback`.
    static func isCallback(_ url: String) -> Bool {
        !scheme.isEmpty && url.lowercased().hasPrefix(scheme + "://")
    }

    /// Called in the short-lived process the browser starts.
    static func deliver(_ url: String) {
        _ = FileManager.default.createFile(atPath: file.path, contents: Data(url.utf8), attributes: [.posixPermissions: 0o600])
    }

    static func wait(timeout: TimeInterval) async throws -> [String: String] {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let url = try? String(contentsOf: file, encoding: .utf8) {
                try? FileManager.default.removeItem(at: file)
                let items = URLComponents(string: url.trimmingCharacters(in: .whitespacesAndNewlines))?.queryItems ?? []
                return Dictionary(items.compactMap { item in item.value.map { (item.name, $0) } }) { a, _ in a }
            }
            try await Task.sleep(for: .milliseconds(300))
        }
        throw LinuxAuthError("Sign-in timed out. Please try again.")
    }

    /// Make this executable the handler for the redirect scheme, like the URL type in the Mac app's Info.plist.
    /// Skipped inside Flatpak, where the manifest's .desktop file declares it.
    static func registerSchemeHandler() {
        guard ProcessInfo.processInfo.environment["FLATPAK_ID"] == nil,
              let exe = Bundle.main.executablePath, !scheme.isEmpty else { return }
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/share/applications")
        let name = "bettermsfile-auth.desktop"
        let entry = """
        [Desktop Entry]
        Type=Application
        Name=BetterMSFile Sign-in
        NoDisplay=true
        Exec="\(exe.replacingOccurrences(of: "\"", with: "\\\""))" --auth-callback %u
        MimeType=x-scheme-handler/\(scheme);

        """
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? entry.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
        run(["xdg-mime", "default", name, "x-scheme-handler/\(scheme)"])
        run(["update-desktop-database", dir.path])
    }

    private static func run(_ args: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }
}
