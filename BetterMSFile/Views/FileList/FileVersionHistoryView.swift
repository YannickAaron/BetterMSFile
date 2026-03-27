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
                ForEach(Array(versions.enumerated()), id: \.element.id) { index, version in
                    // Gap badge between consecutive versions (versions are newest-first)
                    if index > 0 {
                        if let newerDate = parsedDate(for: versions[index - 1]),
                           let olderDate = parsedDate(for: version) {
                            let days = Calendar.current.dateComponents([.day], from: olderDate, to: newerDate).day ?? 0
                            if days > 0 {
                                daysBetweenDivider(days: days)
                            }
                        }
                    }
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

    // MARK: - Sub-views

    @ViewBuilder
    private func daysBetweenDivider(days: Int) -> some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(Color.secondary.opacity(0.12))
                .frame(height: 1)
            Text("\(days) day\(days == 1 ? "" : "s") between versions")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize()
            Rectangle()
                .fill(Color.secondary.opacity(0.12))
                .frame(height: 1)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func versionRow(_ version: GraphDriveItemVersion) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                // Version label
                Text("v\(version.id)")
                    .font(.caption)
                    .fontWeight(.semibold)

                // Absolute date + "X days ago"
                if let dateStr = version.lastModifiedDateTime,
                   let date = parseISO8601(dateStr) {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(relativeTimeLabel(for: date))
                        .font(.caption2)
                        .foregroundStyle(.blue.opacity(0.8))
                }

                // Size + author
                HStack(spacing: 4) {
                    if let size = version.size {
                        Text(size.formattedFileSize)
                    }
                    if let name = version.lastModifiedBy?.user?.displayName {
                        if version.size != nil { Text("·") }
                        Text(name)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            Spacer()

            if downloadingVersionId == version.id {
                ProgressView()
                    .controlSize(.mini)
                    .padding(.top, 2)
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
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Helpers

    private func parsedDate(for version: GraphDriveItemVersion) -> Date? {
        guard let dateStr = version.lastModifiedDateTime else { return nil }
        return parseISO8601(dateStr)
    }

    private func relativeTimeLabel(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.day, .hour, .minute], from: date, to: .now)
        let days = components.day ?? 0
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0

        switch days {
        case let d where d > 365:
            let years = d / 365
            return "\(years) year\(years == 1 ? "" : "s") ago"
        case let d where d > 30:
            let months = d / 30
            return "\(months) month\(months == 1 ? "" : "s") ago"
        case 1...:
            return "\(days) day\(days == 1 ? "" : "s") ago"
        case _ where hours >= 1:
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        case _ where minutes >= 1:
            return "\(minutes) min ago"
        default:
            return "just now"
        }
    }

    private func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    // MARK: - Load & Download

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
}
