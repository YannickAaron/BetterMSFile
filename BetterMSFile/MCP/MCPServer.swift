import Foundation
#if canImport(PDFKit)
import PDFKit
#endif
#if canImport(Glibc)
import Glibc
#endif

/// Headless MCP server: `BetterMSFile --mcp` speaks MCP (JSON-RPC, newline-delimited) over stdio.
/// Reuses the signed-in MSAL session from the keychain; never shows UI.
/// ponytail: hand-rolled tools-only MCP (initialize, tools/list, tools/call, ping) instead of the
/// swift-sdk package; swap in the SDK if we need resources, prompts or HTTP transport.
enum MCPServer {
    static let enabledKey = "mcpEnabled"
    static let allowWritesKey = "mcpAllowWrites"

    private static var out: FileHandle!
    private static let auth = AuthService()
    private static let client = GraphClient(authService: auth)
    private static let files = FileService(client: client)
    private static let sites = SiteService(client: client)
    private static let searcher = SearchService(client: client)

    static func start() -> Never {
        // Protocol owns the real stdout; every stray print() (MSAL, GraphClient) goes to stderr.
        out = FileHandle(fileDescriptor: dup(STDOUT_FILENO))
        dup2(STDERR_FILENO, STDOUT_FILENO)

        Task {
            auth.allowsInteractiveSignIn = false
            await auth.restoreSession()
            // ponytail: requests handled one at a time; spawn a Task per call if agents need parallelism.
            // readLine (not FileHandle.bytes) so the same loop runs on Linux.
            while let line = await Task.detached(operation: { readLine() }).value {
                await handle(line)
            }
            exit(0)
        }
        dispatchMain()
    }

    // MARK: - JSON-RPC

    private static func handle(_ line: String) async {
        guard let data = line.data(using: .utf8),
              let msg = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let method = msg["method"] as? String,
              let id = msg["id"] else { return } // notifications and responses need no reply

        let params = msg["params"] as? [String: Any] ?? [:]
        switch method {
        case "initialize":
            // ponytail: echo the client's protocol version; we only use tools, which are stable across versions.
            reply(id, result: [
                "protocolVersion": params["protocolVersion"] as? String ?? "2025-06-18",
                "capabilities": ["tools": [:]],
                "serverInfo": [
                    "name": "bettermsfile",
                    "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                ],
                "instructions": """
                Access the user's Microsoft 365 files (OneDrive, SharePoint, Teams). \
                Start with list_locations or search. Every file/folder has an `id`; pass it to the other tools.
                """,
            ])
        case "ping":
            reply(id, result: [:])
        case "tools/list":
            reply(id, result: ["tools": visibleTools.map(\.definition)])
        case "tools/call":
            let name = params["name"] as? String ?? ""
            let args = params["arguments"] as? [String: Any] ?? [:]
            reply(id, result: await call(name, args))
        default:
            send(["jsonrpc": "2.0", "id": id, "error": ["code": -32601, "message": "Method not found: \(method)"]])
        }
    }

    private static func reply(_ id: Any, result: [String: Any]) {
        send(["jsonrpc": "2.0", "id": id, "result": result])
    }

    private static func send(_ obj: [String: Any]) {
        guard var data = try? JSONSerialization.data(withJSONObject: obj, options: .withoutEscapingSlashes) else { return }
        data.append(0x0A)
        out.write(data)
    }

    private static func call(_ name: String, _ args: [String: Any]) async -> [String: Any] {
        func text(_ s: String, error: Bool = false) -> [String: Any] {
            ["content": [["type": "text", "text": s]], "isError": error]
        }
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: enabledKey) else {
            return text("Agent access is turned off. Ask the user to enable it in BetterMSFile → Settings → Agents.", error: true)
        }
        guard let tool = visibleTools.first(where: { $0.name == name }) else {
            let hidden = tools.contains { $0.name == name }
            return text(hidden
                ? "\(name) changes files, which is turned off. The user can allow it in BetterMSFile → Settings → Agents."
                : "Unknown tool: \(name)", error: true)
        }
        do {
            return text(try await tool.run(Args(raw: args)))
        } catch AuthError.notSignedIn {
            return text("Not signed in to Microsoft 365. Ask the user to open BetterMSFile and sign in.", error: true)
        } catch {
            return text(error.localizedDescription, error: true)
        }
    }

    // MARK: - Tools

    private struct Tool {
        enum Kind { case read, write, destructive }
        let name: String
        let description: String
        let kind: Kind
        var params: [String: (type: String, description: String)] = [:]
        var required: [String] = []
        let run: (Args) async throws -> String

        var definition: [String: Any] {
            [
                "name": name,
                "description": description,
                "inputSchema": [
                    "type": "object",
                    "properties": params.mapValues { ["type": $0.type, "description": $0.description] },
                    "required": required,
                ],
                "annotations": [
                    "readOnlyHint": kind == .read,
                    "destructiveHint": kind == .destructive,
                    "openWorldHint": true,
                ],
            ]
        }
    }

    private static var visibleTools: [Tool] {
        UserDefaults.standard.bool(forKey: allowWritesKey) ? tools : tools.filter { $0.kind == .read }
    }

    private static let idParam = (type: "string", description: "Item id from a listing or search result")

    private static let tools: [Tool] = [
        Tool(name: "list_locations",
             description: "List where files live: the user's OneDrive plus SharePoint / Teams document libraries. Each has an id to pass to list_folder.",
             kind: .read) { _ in
            let drive = try await files.fetchMyDrive()
            var result: [[String: Any]] = [["name": "OneDrive", "id": "\(drive.id):root", "kind": "onedrive"]]
            for site in try await sites.fetchAllAccessibleSites() {
                for lib in site.drives {
                    result.append([
                        "name": "\(site.displayName) / \(lib.name)",
                        "id": "\(lib.id):root",
                        "kind": site.groupId != nil ? "team" : "sharepoint",
                    ])
                }
            }
            return try json(result)
        },
        Tool(name: "list_folder",
             description: "List the files and folders inside a folder. Omit id for the OneDrive root.",
             kind: .read,
             params: ["id": (type: "string", description: "Folder id (from list_locations, list_folder or search)")]) { args in
            guard let raw = args.string("id") else { return try json(try await files.fetchMyDriveRoot().map(describe)) }
            let ref = try ItemRef(raw)
            return try json(try await files.fetchFolderContents(driveId: ref.driveId, itemId: ref.itemId).map(describe))
        },
        Tool(name: "search",
             description: "Full-text search across OneDrive, SharePoint and Teams files (names and contents). Returns up to 25 results.",
             kind: .read,
             params: [
                "query": (type: "string", description: "What to look for"),
                "file_type": (type: "string", description: "Optional extension filter, e.g. pdf, docx, xlsx"),
             ],
             required: ["query"]) { args in
            let query = try args.require("query")
            let result = try await searcher.search(query: query, filters: SearchFilters(fileType: args.string("file_type")))
            return try json(["results": result.files.map(describe), "moreAvailable": result.moreAvailable])
        },
        Tool(name: "recent_files", description: "Files the user opened or edited recently.", kind: .read) { _ in
            try json(try await files.fetchRecentFiles().map(describe))
        },
        Tool(name: "shared_with_me", description: "Files other people shared with the user.", kind: .read) { _ in
            try json(try await files.fetchSharedWithMe().map(describe))
        },
        Tool(name: "get_info", description: "Details of one file or folder.", kind: .read,
             params: ["id": idParam], required: ["id"]) { args in
            let ref = try ItemRef(try args.require("id"))
            return try json(describe(try await item(ref)))
        },
        Tool(name: "read_file",
             description: "Read a file's text content. Works for text/code/CSV/JSON/Markdown, PDF and Office documents (Word, Excel, PowerPoint). For images or other binaries use download_file.",
             kind: .read, params: ["id": idParam], required: ["id"]) { args in
            try await readText(ItemRef(try args.require("id")))
        },
        Tool(name: "download_file",
             description: "Download a file to the user's computer and return the local path.",
             kind: .read,
             params: ["id": idParam, "to_dir": (type: "string", description: "Local folder, default ~/Downloads")],
             required: ["id"]) { args in
            let ref = try ItemRef(try args.require("id"))
            let file = try await item(ref)
            let dir = args.string("to_dir").map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
                ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
            let temp = try await files.downloadFile(driveId: ref.driveId, itemId: ref.itemId)
            let dest = dir.appendingPathComponent(file.name).uniqueFileURL()
            try FileManager.default.moveItem(at: temp, to: dest)
            return try json(["path": dest.path])
        },
        Tool(name: "upload_file",
             description: "Upload a local file from the user's computer into a folder. If the name exists, a numbered copy is created.",
             kind: .write,
             params: [
                "local_path": (type: "string", description: "Absolute path of the local file"),
                "folder_id": (type: "string", description: "Destination folder id"),
             ],
             required: ["local_path", "folder_id"]) { args in
            let url = URL(fileURLWithPath: (try args.require("local_path") as NSString).expandingTildeInPath)
            let folder = try ItemRef(try args.require("folder_id"))
            let data = try Data(contentsOf: url)
            let uploaded = try await files.upload(data: data, filename: url.lastPathComponent,
                                                  driveId: folder.driveId, parentId: folder.itemId)
            return try json(uploaded.map { describe($0.toUnifiedFile(source: .oneDrive)) } ?? ["uploaded": url.lastPathComponent])
        },
        Tool(name: "create_folder", description: "Create a folder.", kind: .write,
             params: ["parent_id": (type: "string", description: "Parent folder id"),
                      "name": (type: "string", description: "New folder name")],
             required: ["parent_id", "name"]) { args in
            let parent = try ItemRef(try args.require("parent_id"))
            let name = try validName(try args.require("name"))
            let created = try await files.createFolder(driveId: parent.driveId, parentId: parent.itemId, name: name)
            return try json(describe(created.toUnifiedFile(source: .oneDrive)))
        },
        Tool(name: "rename", description: "Rename a file or folder.", kind: .write,
             params: ["id": idParam, "new_name": (type: "string", description: "New name, including extension")],
             required: ["id", "new_name"]) { args in
            let ref = try ItemRef(try args.require("id"))
            let renamed = try await files.renameItem(driveId: ref.driveId, itemId: ref.itemId,
                                                     newName: try validName(try args.require("new_name")))
            return try json(describe(renamed.toUnifiedFile(source: .oneDrive)))
        },
        Tool(name: "move", description: "Move a file or folder into another folder on the same drive.", kind: .write,
             params: ["id": idParam, "folder_id": (type: "string", description: "Destination folder id")],
             required: ["id", "folder_id"]) { args in
            let ref = try ItemRef(try args.require("id"))
            let folder = try ItemRef(try args.require("folder_id"))
            guard ref.driveId == folder.driveId else { throw MoveError.crossDriveNotSupported }
            let moved = try await files.moveItem(driveId: ref.driveId, itemId: ref.itemId, toFolderId: folder.itemId)
            return try json(describe(moved.toUnifiedFile(source: .oneDrive)))
        },
        Tool(name: "delete", description: "Delete a file or folder (moves it to the Microsoft 365 recycle bin).",
             kind: .destructive, params: ["id": idParam], required: ["id"]) { args in
            let ref = try ItemRef(try args.require("id"))
            try await files.deleteItem(driveId: ref.driveId, itemId: ref.itemId)
            return "Deleted. It can be restored from the recycle bin."
        },
    ]

    // MARK: - Helpers

    private static func item(_ ref: ItemRef) async throws -> UnifiedFile {
        let file = try await files.fetchItem(driveId: ref.driveId, itemId: ref.itemId).toUnifiedFile(source: .oneDrive)
        if file.driveId.isEmpty { file.driveId = ref.driveId } // drive roots have no parentReference
        return file
    }

    private static let officeExtensions: Set<String> = [
        "doc", "docx", "xls", "xlsx", "xlsm", "ppt", "pptx", "pps", "ppsx", "odt", "ods", "odp", "rtf", "msg", "eml",
    ]
    private static let maxChars = 100_000

    private static func readText(_ ref: ItemRef) async throws -> String {
        let file = try await item(ref)
        guard !file.isFolder else { throw ToolError("That id is a folder. Use list_folder.") }
        guard file.size <= 50_000_000 else { throw ToolError("File is too large to read (\(file.size) bytes). Use download_file.") }

        let ext = (file.name as NSString).pathExtension.lowercased()
        var content = GraphEndpoints.driveItemContent(driveId: ref.driveId, itemId: ref.itemId)
        if officeExtensions.contains(ext) {
            // Graph renders Office files to PDF server-side; PDFKit extracts the text.
            content.append(queryItems: [URLQueryItem(name: "format", value: "pdf")])
        }
        let temp = try await client.downloadFile(content)
        defer { try? FileManager.default.removeItem(at: temp) }

        var text: String
        if ext == "pdf" || officeExtensions.contains(ext) {
            text = try pdfText(temp, name: file.name)
        } else {
            let data = try Data(contentsOf: temp)
            guard !data.contains(0), let decoded = String(data: data, encoding: .utf8) else {
                throw ToolError("\(file.name) is not a text file. Use download_file instead.")
            }
            text = decoded
        }
        if text.count > maxChars {
            text = String(text.prefix(maxChars)) + "\n\n[Truncated: showing the first \(maxChars) characters. Use download_file for the full file.]"
        }
        return text
    }

    #if canImport(PDFKit)
    private static func pdfText(_ url: URL, name: String) throws -> String {
        guard let pdf = PDFDocument(url: url) else { throw ToolError("Could not read \(name).") }
        return pdf.string ?? ""
    }
    #else
    /// No PDFKit on Linux: poppler's `pdftotext` (package poppler-utils).
    private static func pdfText(_ url: URL, name: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["pdftotext", "-layout", url.path, "-"]
        let pipe = Pipe()
        process.standardOutput = pipe
        do { try process.run() } catch { throw ToolError("Reading PDFs needs pdftotext (install poppler-utils).") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw ToolError("Could not read \(name).") }
        return String(decoding: data, as: UTF8.self)
    }
    #endif

    private static func describe(_ f: UnifiedFile) -> [String: Any] {
        var d: [String: Any] = [
            "id": "\(f.driveId):\(f.itemId)",
            "name": f.name,
            "type": f.isFolder ? "folder" : "file",
            "modified": ISO8601DateFormatter().string(from: f.modifiedAt),
            "webUrl": f.webURL,
        ]
        if !f.isFolder { d["size"] = f.size }
        if let by = f.modifiedBy { d["modifiedBy"] = by }
        if let range = f.parentPath.range(of: "root:") { d["path"] = String(f.parentPath[range.upperBound...]) + "/" + f.name }
        return d
    }

    private static func json(_ value: Any) throws -> String {
        String(decoding: try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .withoutEscapingSlashes]), as: UTF8.self)
    }

    /// OneDrive/SharePoint reject these; fail early with a clear message.
    static func validName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.rangeOfCharacter(from: CharacterSet(charactersIn: "\"*:<>?/\\|")) == nil,
              !trimmed.hasSuffix(".") else {
            throw ToolError("Invalid name \"\(name)\". Names can't be empty, end with a dot, or contain \" * : < > ? / \\ |")
        }
        return trimmed
    }
}

/// `"driveId:itemId"`, the id format every tool returns and accepts.
private struct ItemRef {
    let driveId: String
    let itemId: String

    init(_ raw: String) throws {
        let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
            throw ToolError("Invalid id \"\(raw)\". Use an id returned by list_locations, list_folder or search.")
        }
        driveId = parts[0]
        itemId = parts[1]
    }
}

private struct Args {
    let raw: [String: Any]
    func string(_ key: String) -> String? {
        (raw[key] as? String).flatMap { $0.isEmpty ? nil : $0 }
    }
    func require(_ key: String) throws -> String {
        guard let value = string(key) else { throw ToolError("Missing required argument: \(key)") }
        return value
    }
}

private struct ToolError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}
