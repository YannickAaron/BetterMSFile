import Foundation

extension URL {
    /// Unique file path: appends a counter if the file already exists (`report (1).pdf`).
    func uniqueFileURL() -> URL {
        guard FileManager.default.fileExists(atPath: path) else { return self }

        let directory = deletingLastPathComponent()
        let stem = deletingPathExtension().lastPathComponent
        let ext = pathExtension

        var counter = 1
        var candidate: URL
        repeat {
            let newName = ext.isEmpty ? "\(stem) (\(counter))" : "\(stem) (\(counter)).\(ext)"
            candidate = directory.appendingPathComponent(newName)
            counter += 1
        } while FileManager.default.fileExists(atPath: candidate.path)

        return candidate
    }
}
