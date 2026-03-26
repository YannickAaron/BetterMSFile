import Foundation

@Observable
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
        _ = try? await authService.getAccessToken()
    }

    private func fetchUserProfile() async {
        do {
            let token = try await authService.getAccessToken()
            let url = URL(string: "https://graph.microsoft.com/v1.0/me")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, _) = try await URLSession.shared.data(for: request)
            let profile = try JSONDecoder().decode(UserProfile.self, from: data)
            userName = profile.displayName
            userEmail = profile.mail ?? profile.userPrincipalName
        } catch {
            print("Failed to fetch profile: \(error.localizedDescription)")
        }
    }
}

private struct UserProfile: Codable {
    let displayName: String?
    let mail: String?
    let userPrincipalName: String?
}
