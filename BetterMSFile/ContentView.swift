import SwiftUI

struct ContentView: View {
    let appState: AppState
    @State private var showUpdateAlert = false
    @State private var hasShownUpdateAlert = false

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
        .onChange(of: appState.updateService.updateAvailable) { _, available in
            if available && !hasShownUpdateAlert {
                showUpdateAlert = true
            }
        }
        .alert("Update Available", isPresented: $showUpdateAlert) {
            Button("Download") {
                if let url = appState.updateService.downloadURL {
                    NSWorkspace.shared.open(url)
                }
                hasShownUpdateAlert = true
            }
            Button("Later", role: .cancel) {
                hasShownUpdateAlert = true
            }
        } message: {
            let latest = appState.updateService.latestVersion ?? "unknown"
            let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
            Text("BetterMSFile \(latest) is available. You're running \(current).")
        }
    }
}
