import Foundation

@MainActor @Observable
final class AuthViewModel {
    let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    var isAuthenticated: Bool { appState.authService.isAuthenticated }
    var isLoading: Bool { appState.isLoading }
    var errorMessage: String? { appState.errorMessage }
    var userName: String? { appState.userName }
    var userEmail: String? { appState.userEmail }

    func signIn() async {
        await appState.signIn()
    }

    func signOut() async {
        await appState.signOut()
    }
}
