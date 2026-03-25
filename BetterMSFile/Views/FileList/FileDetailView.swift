import SwiftUI

struct FileDetailView: View {
    let file: UnifiedFile
    var onShowInFolder: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: file.isFolder ? "folder.fill" : "doc")
                    .font(.title)
                    .foregroundStyle(file.isFolder ? .blue : .secondary)
                Text(file.name)
                    .font(.title3)
                    .fontWeight(.medium)
                    .lineLimit(2)
            }

            Divider()

            // Metadata
            Group {
                detailRow("Size", value: file.size.formattedFileSize)
                detailRow("Modified", value: file.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                detailRow("Created", value: file.createdAt.formatted(date: .abbreviated, time: .shortened))

                if let modifiedBy = file.modifiedBy {
                    detailRow("Modified by", value: modifiedBy)
                }

                detailRow("Source", value: file.source.displayName)

                if let mimeType = file.mimeType {
                    detailRow("Type", value: mimeType)
                }
            }

            Divider()

            // Actions
            VStack(spacing: 8) {
                Button {
                    if let url = URL(string: file.webURL) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Open in Browser", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(file.webURL, forType: .string)
                } label: {
                    Label("Copy Link", systemImage: "link")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                if let onShowInFolder {
                    Button {
                        onShowInFolder()
                    } label: {
                        Label("Show in Folder", systemImage: "folder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 200)
    }

    private func detailRow(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
        }
    }
}
