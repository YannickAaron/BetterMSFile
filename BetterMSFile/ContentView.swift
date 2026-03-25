import SwiftUI

struct ContentView: View {
    let appState: AppState

    var body: some View {
        Group {
            if appState.isLoading && !appState.authService.isAuthenticated {
                ProgressView("Restoring session...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appState.authService.isAuthenticated {
                MainView(appState: appState)
            } else {
                LoginView(viewModel: AuthViewModel(appState: appState))
            }
        }
        .frame(minWidth: 800, minHeight: 500)
    }
}
