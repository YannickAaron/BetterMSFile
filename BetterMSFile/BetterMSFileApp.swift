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
                    cleanupTempFiles()
                    await appState.restoreSession()
                }
.onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    // Background refresh when app becomes active
                    Task { await appState.backgroundRefresh() }
                    // Check for updates (debounced inside UpdateService)
                    Task { await appState.updateService.checkForUpdate() }
                }
        }
        .modelContainer(for: [UnifiedFile.self, FavoriteItem.self, FileAccessRecord.self, CustomSortOrder.self])
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandMenu("Search") {
                Button("Find Files...") {
                    NotificationCenter.default.post(name: .activateSearch, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
            }

            CommandMenu("File") {
                Button("New Folder") {
                    NotificationCenter.default.post(name: .createNewFolder, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("Rename") {
                    NotificationCenter.default.post(name: .renameSelectedFile, object: nil)
                }
                .keyboardShortcut(.return, modifiers: [])

                Button("Toggle Favorite") {
                    NotificationCenter.default.post(name: .toggleFavorite, object: nil)
                }
                .keyboardShortcut("d", modifiers: .command)
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

    /// Remove stale temp files from previous Quick Look sessions.
    private func cleanupTempFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: tempDir, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles
        ) else { return }

        let cutoff = Date.now.addingTimeInterval(-24 * 60 * 60) // older than 24 hours
        for fileURL in contents {
            if let attrs = try? fileURL.resourceValues(forKeys: [.creationDateKey]),
               let created = attrs.creationDate,
               created < cutoff {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let activateSearch = Notification.Name("activateSearch")
    static let navigateBack = Notification.Name("navigateBack")
    static let navigateForward = Notification.Name("navigateForward")
    static let toggleFavorite = Notification.Name("toggleFavorite")
    static let createNewFolder = Notification.Name("createNewFolder")
    static let renameSelectedFile = Notification.Name("renameSelectedFile")
}
