import Foundation
import MSAL

@Observable
final class AuthService {
    private(set) var currentAccount: MSALAccount?
    private(set) var accessToken: String?
    private(set) var isAuthenticated = false

    private var application: MSALPublicClientApplication?

    init() {
        do {
            let authority = try MSALAADAuthority(url: URL(string: MSALConfig.authority)!)
            let config = MSALPublicClientApplicationConfig(
                clientId: MSALConfig.clientId,
                redirectUri: MSALConfig.redirectUri,
                authority: authority
            )
            config.cacheConfig.keychainSharingGroup = "com.microsoft.identity.universalstorage"
            application = try MSALPublicClientApplication(configuration: config)

            MSALGlobalConfig.loggerConfig.logLevel = .verbose
            MSALGlobalConfig.loggerConfig.logMaskingLevel = .settingsMaskAllPII
        } catch {
            print("Failed to initialize MSAL: \(error.localizedDescription)")
        }
    }

    /// Try to restore a previously signed-in account silently.
    func restoreSession() async {
        guard let application else { return }
        do {
            let accounts = try application.allAccounts()
            guard let account = accounts.first else { return }
            let result = try await acquireTokenSilently(account: account)
            self.currentAccount = result.account
            self.accessToken = result.accessToken
            self.isAuthenticated = true
        } catch {
            // Silent restore failed — user will need to sign in interactively
            print("Session restore failed: \(error.localizedDescription)")
        }
    }

    /// Sign in interactively via a browser sheet.
    func signIn() async throws {
        guard let application else {
            throw AuthError.msalNotInitialized
        }

        let webviewParams = MSALWebviewParameters()
        let parameters = MSALInteractiveTokenParameters(
            scopes: MSALConfig.scopes,
            webviewParameters: webviewParams
        )
        parameters.promptType = .selectAccount

        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<MSALResult, Error>) in
            application.acquireToken(with: parameters) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: AuthError.unknownError)
                }
            }
        }

        self.currentAccount = result.account
        self.accessToken = result.accessToken
        self.isAuthenticated = true
    }

    /// Sign out and clear cached tokens.
    func signOut() async throws {
        guard let application, let account = currentAccount else { return }

        let parameters = MSALSignoutParameters(webviewParameters: MSALWebviewParameters())
        parameters.signoutFromBrowser = false

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            application.signout(with: account, signoutParameters: parameters) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }

        self.currentAccount = nil
        self.accessToken = nil
        self.isAuthenticated = false
    }

    /// Acquire a fresh access token. Call before each Graph API request.
    /// MSAL handles token caching and refresh automatically.
    func getAccessToken() async throws -> String {
        guard let account = currentAccount else {
            throw AuthError.notSignedIn
        }

        do {
            let result = try await acquireTokenSilently(account: account)
            self.accessToken = result.accessToken
            return result.accessToken
        } catch {
            // Silent token refresh failed (e.g., refresh token expired)
            // Try interactive sign-in as last resort
            do {
                try await signIn()
                guard let token = accessToken else {
                    throw AuthError.tokenAcquisitionFailed
                }
                return token
            } catch {
                // Interactive login also failed — clear auth state
                self.isAuthenticated = false
                self.accessToken = nil
                throw error
            }
        }
    }

    // MARK: - Private

    private func acquireTokenSilently(account: MSALAccount) async throws -> MSALResult {
        guard let application else {
            throw AuthError.msalNotInitialized
        }

        let parameters = MSALSilentTokenParameters(scopes: MSALConfig.scopes, account: account)

        return try await withCheckedThrowingContinuation { continuation in
            application.acquireTokenSilent(with: parameters) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: AuthError.unknownError)
                }
            }
        }
    }
}

enum AuthError: LocalizedError {
    case msalNotInitialized
    case notSignedIn
    case tokenAcquisitionFailed
    case unknownError

    var errorDescription: String? {
        switch self {
        case .msalNotInitialized: "MSAL failed to initialize. Check your Config.swift values."
        case .notSignedIn: "No signed-in account. Please sign in first."
        case .tokenAcquisitionFailed: "Failed to acquire access token."
        case .unknownError: "An unknown authentication error occurred."
        }
    }
}
