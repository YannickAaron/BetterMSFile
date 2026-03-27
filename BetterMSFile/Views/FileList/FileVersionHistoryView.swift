import SwiftUI

struct FileVersionHistoryView: View {
    let file: UnifiedFile
    let fileService: FileService
    @State private var versions: [GraphDriveItemVersion] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var downloadingVersionId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Version History")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                }
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
            } else if versions.isEmpty && !isLoading {
                Text("No version history available")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(versions, id: \.id) { version in
                    versionRow(version)
                }
            }
        }
        .task {
            await loadVersions()
        }
        .onChange(of: file.uniqueId) { _, _ in
            Task { await loadVersions() }
        }
    }

    @ViewBuilder
    private func versionRow(_ version: GraphDriveItemVersion) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("v\(version.id)")
                    .font(.caption)
                    .fontWeight(.medium)
                HStack(spacing: 4) {
                    if let dateStr = version.lastModifiedDateTime,
                       let date = parseISO8601(dateStr) {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                    }
                    if let size = version.size {
                        Text("·")
                        Text(size.formattedFileSize)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)

                if let name = version.lastModifiedBy?.user?.displayName {
                    Text(name)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if downloadingVersionId == version.id {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Button {
                    Task { await downloadVersion(version) }
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Download this version")
            }
        }
        .padding(.vertical, 2)
    }

    private func loadVersions() async {
        guard !file.isFolder, !file.driveId.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            versions = try await fileService.fetchVersions(driveId: file.driveId, itemId: file.itemId)
        } catch {
            errorMessage = "Could not load versions"
        }
        isLoading = false
    }

    private func downloadVersion(_ version: GraphDriveItemVersion) async {
        downloadingVersionId = version.id
        defer { downloadingVersionId = nil }

        do {
            guard let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else { return }
            let stem = (file.name as NSString).deletingPathExtension
            let ext = (file.name as NSString).pathExtension
            let versionName = ext.isEmpty ? "\(stem) (v\(version.id))" : "\(stem) (v\(version.id)).\(ext)"
            var destinationURL = downloadsDir.appendingPathComponent(versionName)

            // Collision resolution
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                var counter = 1
                repeat {
                    let name = ext.isEmpty ? "\(stem) (v\(version.id)) (\(counter))" : "\(stem) (v\(version.id)) (\(counter)).\(ext)"
                    destinationURL = downloadsDir.appendingPathComponent(name)
                    counter += 1
                } while FileManager.default.fileExists(atPath: destinationURL.path)
            }

            let tempURL = try await fileService.downloadVersion(driveId: file.driveId, itemId: file.itemId, versionId: version.id)
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)
            NSWorkspace.shared.selectFile(destinationURL.path, inFileViewerRootedAtPath: downloadsDir.path)
        } catch {
            // Silently fail — download button will just stop spinning
        }
    }

    private func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }
}
