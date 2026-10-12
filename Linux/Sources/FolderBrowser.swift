import Foundation
import Observation

/// Linux counterpart of FileListViewModel (which is tied to SwiftData): folder navigation + file actions.
/// ponytail: no offline cache or custom sort order; add a JSON cache if loading feels slow.
@Observable
final class FolderBrowser {
    enum Location: Equatable {
        case myDrive, recent, shared
        case driveRoot(driveId: String, name: String, source: FileSource)
        case folder(driveId: String, itemId: String, name: String, source: FileSource)

        var title: String {
            switch self {
            case .myDrive: "OneDrive"
            case .recent: "Recent"
            case .shared: "Shared with Me"
            case .driveRoot(_, let name, _), .folder(_, _, let name, _): name
            }
        }

        var driveId: String? {
            switch self {
            case .driveRoot(let id, _, _), .folder(let id, _, _, _): id
            default: nil
            }
        }

        var source: FileSource {
            switch self {
            case .driveRoot(_, _, let source), .folder(_, _, _, let source): source
            case .shared: .shared
            default: .oneDrive
            }
        }
    }

    private let fileService: FileService

    private(set) var path: [Location] = [.myDrive]
    private(set) var files: [UnifiedFile] = []
    private(set) var isLoading = false
    var errorMessage: String?
    private var loadTask: Task<Void, Never>?

    var current: Location { path.last ?? .myDrive }
    var canGoBack: Bool { path.count > 1 }
    /// Parent path for the window subtitle ("OneDrive › Projects"); empty at the top level.
    var breadcrumb: String { path.dropLast().map(\.title).joined(separator: " › ") }

    /// Where "New Folder" creates into; nil for virtual lists (Recent, Shared).
    var folderTarget: (driveId: String, itemId: String)? {
        switch current {
        case .folder(let driveId, let itemId, _, _): (driveId, itemId)
        case .driveRoot(let driveId, _, _): (driveId, "root")
        case .myDrive: myDriveId.map { ($0, "root") }
        default: nil
        }
    }
    private var myDriveId: String?

    init(fileService: FileService) {
        self.fileService = fileService
    }

    /// Sidebar selection: start a new path.
    func show(_ location: Location) {
        path = [location]
        reload()
    }

    func open(_ file: UnifiedFile) {
        guard file.isFolder else { return }
        path.append(.folder(driveId: file.driveId, itemId: file.itemId, name: file.name, source: current.source))
        reload()
    }

    func goBack() {
        guard canGoBack else { return }
        path.removeLast()
        reload()
    }

    func reload() {
        // Cancel the previous load so a slow, stale response can't overwrite the current folder.
        loadTask?.cancel()
        let location = current
        isLoading = true
        errorMessage = nil
        files = []
        loadTask = Task {
            do {
                let loaded = try await fetch(location)
                guard !Task.isCancelled else { return }
                files = loaded.sorted { a, b in
                    a.isFolder != b.isFolder ? a.isFolder : a.name.localizedStandardCompare(b.name) == .orderedAscending
                }
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func fetch(_ location: Location) async throws -> [UnifiedFile] {
        switch location {
        case .myDrive:
            if myDriveId == nil { myDriveId = try await fileService.fetchMyDrive().id }
            return try await fileService.fetchMyDriveRoot()
        case .recent: return try await fileService.fetchRecentFiles()
        case .shared: return try await fileService.fetchSharedWithMe()
        case .driveRoot(let driveId, _, let source):
            return try await fileService.fetchDriveRoot(driveId: driveId, source: source)
        case .folder(let driveId, let itemId, _, let source):
            return try await fileService.fetchFolderContents(driveId: driveId, itemId: itemId, source: source)
        }
    }

    // MARK: - File actions (throw; the view shows an alert)

    func createFolder(named name: String) async throws {
        guard let target = folderTarget else { return }
        _ = try await fileService.createFolder(driveId: target.driveId, parentId: target.itemId,
                                               name: try MCPServer.validName(name))
        reload()
    }

    func rename(_ file: UnifiedFile, to name: String) async throws {
        _ = try await fileService.renameItem(driveId: file.driveId, itemId: file.itemId,
                                             newName: try MCPServer.validName(name))
        reload()
    }

    func delete(_ file: UnifiedFile) async throws {
        try await fileService.deleteItem(driveId: file.driveId, itemId: file.itemId)
        reload()
    }

    /// Downloads to ~/Downloads with `name (1).ext` on collisions; returns the local file.
    func download(_ file: UnifiedFile) async throws -> URL {
        let temp = try await fileService.downloadFile(driveId: file.driveId, itemId: file.itemId)
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        let dest = downloads.appendingPathComponent(file.name).uniqueFileURL()
        try FileManager.default.moveItem(at: temp, to: dest)
        return dest
    }

    /// Opens a file in its default local app (like double-clicking in Finder on the Mac).
    func openLocally(_ file: UnifiedFile) async throws {
        let temp = try await fileService.downloadFile(driveId: file.driveId, itemId: file.itemId)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("BetterMSFile-open/\(file.uniqueId)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(file.name)
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: temp, to: dest)
        try Desktop.open(dest.path)
    }
}

/// xdg-open: the Linux equivalent of NSWorkspace.open.
enum Desktop {
    static func open(_ target: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["xdg-open", target]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }
}
