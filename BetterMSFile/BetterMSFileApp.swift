import SwiftUI
import SwiftData

@main
struct BetterMSFileApp: App {
    @State private var appState = AppState()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState)
                .task {
                    await appState.restoreSession()
                }
.onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    // Background refresh when app becomes active
                    Task { await appState.backgroundRefresh() }
                }
        }
        .modelContainer(for: UnifiedFile.self)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandMenu("Search") {
                Button("Find Files...") {
                    NotificationCenter.default.post(name: .activateSearch, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
            }

            CommandMenu("Navigation") {
                Button("Back") {
                    NotificationCenter.default.post(name: .navigateBack, object: nil)
                }
                .keyboardShortcut("[", modifiers: .command)

                Button("Forward") {
                    NotificationCenter.default.post(name: .navigateForward, object: nil)
                }
                .keyboardShortcut("]", modifiers: .command)
            }
        }

        // Menu bar extra for quick access
        MenuBarExtra("BetterMSFile", systemImage: "externaldrive.connected.to.line.below") {
            if appState.authService.isAuthenticated {
                if let name = appState.userName {
                    Text("Signed in as \(name)")
                        .foregroundStyle(.secondary)
                }
                Divider()
                Button("Open BetterMSFile") {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])
                Button("Search Files...") {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(name: .activateSearch, object: nil)
                    }
                }
                Divider()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            } else {
                Text("Not signed in")
                Button("Open & Sign In") {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let activateSearch = Notification.Name("activateSearch")
    static let navigateBack = Notification.Name("navigateBack")
    static let navigateForward = Notification.Name("navigateForward")
}
