import Foundation
import Meta

// Same binary for everything, like the Mac app: GUI by default, plus CLI commands and the MCP server.
let args = CommandLine.arguments

if let i = args.firstIndex(of: "--auth-callback"), let url = args.dropFirst(i + 1).first {
    AuthCallback.deliver(url) // started by the browser for the sign-in redirect
    exit(0)
}
if args.contains("--mcp") {
    MCPServer.start()
}

let usage = """
Usage: bettermsfile [command]

  (no command)             Open the app
  --login                  Sign in to Microsoft 365 in your browser
  --logout                 Sign out and remove the stored sign-in
  --agent-access off|read|write
                           Let AI agents (MCP) read your files, or also change them
  --mcp                    Run as an MCP server over stdio (for Claude Code, Cursor, …)

Add to Claude Code:  claude mcp add bettermsfile -- bettermsfile --mcp

"""

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(1)
}

let cliCommands = ["--login", "--logout", "--agent-access", "--help", "-h"]
guard args.contains(where: cliCommands.contains) else {
    MainActor.assumeIsolated { LinuxApp.main() } // top-level code runs on the main thread
    exit(0)
}

Task { @MainActor in
    let auth = AuthService()
    do {
        if args.contains("--login") {
            try await auth.signIn()
            print("Signed in. Turn on agent access with: bettermsfile --agent-access read")
        } else if args.contains("--logout") {
            try await auth.signOut()
            print("Signed out.")
        } else if let i = args.firstIndex(of: "--agent-access") {
            let level = args.dropFirst(i + 1).first ?? ""
            guard ["off", "read", "write"].contains(level) else { fail(usage) }
            AgentAccess.set(level)
            print("Agent access: \(level).")
        } else {
            print(usage, terminator: "")
        }
        exit(0)
    } catch {
        fail(error.localizedDescription)
    }
}
dispatchMain()
