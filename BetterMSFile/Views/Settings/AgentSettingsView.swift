import SwiftUI

/// Settings → Agents: turn on the MCP server and connect it to AI apps in one click.
struct AgentSettingsView: View {
    var appState: AppState

    @AppStorage(MCPServer.enabledKey) private var enabled = false
    @AppStorage(MCPServer.allowWritesKey) private var allowWrites = false
    @State private var message: String?
    @State private var errorMessage: String?

    private var executablePath: String { Bundle.main.executablePath ?? "" }

    var body: some View {
        Form {
            Section {
                Toggle("Let AI agents access my files", isOn: $enabled)
                Toggle("Allow agents to make changes", isOn: $allowWrites)
                    .disabled(!enabled)
                Text(allowWrites
                     ? "Agents can upload, rename, move, create folders and delete (to the recycle bin)."
                     : "Agents can browse, search, read and download files, but not change anything.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } footer: {
                if let email = appState.userEmail {
                    Label("Agents act as \(email).", systemImage: "person.crop.circle.badge.checkmark")
                        .font(.caption)
                } else {
                    Label("Sign in to BetterMSFile first. Agents use your session.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                }
            }

            Section("Connect an app") {
                LabeledContent("Claude Desktop") {
                    Button("Add to Claude") { addToClaudeDesktop() }
                }
                LabeledContent("Claude Code") {
                    Button("Copy Command") { copy("claude mcp add bettermsfile -- \"\(executablePath)\" --mcp") }
                }
                LabeledContent("Other apps (Cursor, VS Code…)") {
                    Button("Copy JSON") { copy(configJSON) }
                }
                if !executablePath.hasPrefix("/Applications/") {
                    Label("Move BetterMSFile to Applications first. Connected apps break if the app moves later.",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .disabled(!enabled)

            if let message {
                Text(message).font(.caption).foregroundStyle(.green)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .alert("Couldn't update Claude", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var serverEntry: [String: Any] {
        ["command": executablePath, "args": ["--mcp"]]
    }

    private var configJSON: String {
        let data = try? JSONSerialization.data(
            withJSONObject: ["mcpServers": ["bettermsfile": serverEntry]],
            options: [.prettyPrinted, .withoutEscapingSlashes]
        )
        return data.map { String(decoding: $0, as: UTF8.self) } ?? ""
    }

    private func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        message = "Copied to clipboard."
    }

    /// Merge our entry into Claude Desktop's config, keeping everything else. Backs up the old file first.
    private func addToClaudeDesktop() {
        let fm = FileManager.default
        let dir = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Claude")
        let file = dir.appendingPathComponent("claude_desktop_config.json")
        do {
            var config: [String: Any] = [:]
            if let data = try? Data(contentsOf: file) {
                guard let existing = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                config = existing
                let backup = dir.appendingPathComponent("claude_desktop_config.json.bak")
                try? fm.removeItem(at: backup)
                try fm.copyItem(at: file, to: backup)
            }
            var servers = config["mcpServers"] as? [String: Any] ?? [:]
            servers["bettermsfile"] = serverEntry
            config["mcpServers"] = servers

            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .withoutEscapingSlashes])
            try data.write(to: file, options: .atomic)
            message = "Added. Quit and reopen Claude to start using it."
        } catch {
            errorMessage = "\(error.localizedDescription)\n\(file.path)"
        }
    }
}
