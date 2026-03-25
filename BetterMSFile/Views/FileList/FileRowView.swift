import SwiftUI

struct FileRowView: View {
    let file: UnifiedFile

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if !file.isFolder {
                        Text(file.size.formattedFileSize)
                    }
                    Text(file.modifiedAt.relativeFormatted)

                    if let modifiedBy = file.modifiedBy {
                        Text(modifiedBy)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Source badge for non-OneDrive files
            if case .sharePoint(let siteName, _) = file.source {
                Text(siteName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())
            } else if case .shared = file.source {
                Image(systemName: "person.2")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }

    private var iconName: String {
        if file.isFolder { return "folder.fill" }
        guard let mimeType = file.mimeType else { return "doc" }

        return switch mimeType {
        case let m where m.contains("pdf"): "doc.richtext"
        case let m where m.contains("word") || m.contains("document"): "doc.text"
        case let m where m.contains("spreadsheet") || m.contains("excel"): "tablecells"
        case let m where m.contains("presentation") || m.contains("powerpoint"): "rectangle.stack"
        case let m where m.contains("image"): "photo"
        case let m where m.contains("video"): "film"
        case let m where m.contains("audio"): "music.note"
        case let m where m.contains("zip") || m.contains("compressed"): "doc.zipper"
        case let m where m.contains("text"): "doc.plaintext"
        default: "doc"
        }
    }

    private var iconColor: Color {
        if file.isFolder { return .blue }
        guard let mimeType = file.mimeType else { return .secondary }

        return switch mimeType {
        case let m where m.contains("pdf"): .red
        case let m where m.contains("word") || m.contains("document"): .blue
        case let m where m.contains("spreadsheet") || m.contains("excel"): .green
        case let m where m.contains("presentation") || m.contains("powerpoint"): .orange
        case let m where m.contains("image"): .purple
        default: .secondary
        }
    }
}
