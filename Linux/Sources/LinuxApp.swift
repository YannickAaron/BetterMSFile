import Adwaita
import CAdw
import Foundation
import Observation

/// GNOME app shell. Mirrors BetterMSFileApp: one window, shared AppState / view models underneath.
struct LinuxApp: App {
    var app = AdwaitaApp(id: "com.empa.BetterMSFile")

    init() {
        // GTK runs GLib's main loop, which never drains Swift's main queue, so @MainActor tasks would never run.
        // ponytail: 10ms poll; replace with a GLib source on the main queue's eventfd if idle CPU ever matters.
        g_timeout_add(10, { _ in
            RunLoop.main.run(until: Date())
            return 1
        }, nil)
    }

    var scene: Scene {
        Window(id: "main") { _ in
            RootView()
        }
        .title("BetterMSFile")
        .defaultSize(width: 1000, height: 680)
        .closeShortcut()
    }
}

/// Bridges Swift Observation to Meta's state system: views wrap reads of @Observable models in `observe { }`,
/// and any change re-renders the window (Meta re-renders globally on any @State change anyway).
enum Refresh {
    fileprivate static var handler: () -> Void = {}
    private static var pending = false

    static func request() {
        guard !pending else { return }
        pending = true
        Task { @MainActor in
            pending = false
            handler()
        }
    }
}

func observe<T>(_ body: () -> T) -> T {
    withObservationTracking(body) {
        Task { @MainActor in Refresh.request() }
    }
}

struct RootView: View {
    @State private var tick = 0
    @State private var session = Session()

    var view: Body {
        let _ = tick
        let _ = Refresh.handler = { tick += 1 }
        VStack {
            if observe({ session.appState.authService.isAuthenticated }) {
                MainView(session: session)
            } else {
                LoginView(appState: session.appState)
            }
        }
        .vexpand()
        .onAppear {
            Task { await session.appState.restoreSession() }
        }
    }
}

/// Agent (MCP) access switches; same UserDefaults keys the MCP server and the Mac Settings → Agents use.
enum AgentAccess {
    static var level: String {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: MCPServer.enabledKey) else { return "off" }
        return defaults.bool(forKey: MCPServer.allowWritesKey) ? "write" : "read"
    }

    static func set(_ level: String) {
        let defaults = UserDefaults.standard
        defaults.set(level != "off", forKey: MCPServer.enabledKey)
        defaults.set(level == "write", forKey: MCPServer.allowWritesKey)
        defaults.synchronize() // CLI exits right after
    }
}
