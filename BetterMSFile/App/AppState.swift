import Foundation

@MainActor @Observable
final class AppState {
    let authService = AuthService()
    private(set) var graphClient: GraphClient!
    private(set) var fileService: FileService!
    private(set) var siteService: SiteService!
    private(set) var searchService: SearchService!
    let updateService = UpdateService()

    var userName: String?
    var userEmail: String?

    var isLoading = false
    var errorMessage: String?

    init() {
        graphClient = GraphClient(authService: authService)
        fileService = FileService(client: graphClient)
        siteService = SiteService(client: graphClient)
        searchService = SearchService(client: graphClient)
    }

    func restoreSession() async {
        isLoading = true
        await authService.restoreSession()
        if authService.isAuthenticated {
            await fetchUserProfile()
        }
        isLoading = false

        // Check for app updates (auth-independent)
        await updateService.checkForUpdate()
    }

    func signIn() async {
        isLoading = true
        errorMessage = nil
        do {
            try await authService.signIn()
            await fetchUserProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signOut() async {
        do {
            try await authService.signOut()
            userName = nil
            userEmail = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func backgroundRefresh() async {
        guard authService.isAuthenticated else { return }
        // Re-fetch the token silently to keep it fresh
        do {
            _ = try await authService.getAccessToken()
        } catch {
            // Token refresh failed — mark as unauthenticated so the UI shows sign-in
            print("Background token refresh failed: \(error.localizedDescription)")
        }
    }

    private func fetchUserProfile() async {
        do {
            let profile: UserProfile = try await graphClient.getSingle(GraphEndpoints.me)
            userName = profile.displayName
            userEmail = profile.mail ?? profile.userPrincipalName
        } catch {
            print("Failed to fetch profile: \(error.localizedDescription)")
        }
    }
}

struct UserProfile: Codable {
    let displayName: String?
    let mail: String?
    let userPrincipalName: String?
}
