import SwiftUI

@main
enum Entry {
    static func main() {
        if CommandLine.arguments.contains("--mcp") {
            MCPServer.start()
        }
        BetterMSFileApp.main()
    }
}
