import SwiftUI

struct FileRowView: View {
    let file: UnifiedFile

    var body: some View {
        HStack(spacing: 10) {
            fileIconView
                .frame(width: 28, height: 28)

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

    @ViewBuilder
    private var fileIconView: some View {
        if file.isFolder {
            Image(systemName: "folder.fill")
                .font(.title2)
                .foregroundStyle(.blue)
        } else if let msIcon = MSAppIcon.forFile(mimeType: file.mimeType, fileName: file.name) {
            msIcon.icon(size: 24)
        } else {
            Image(systemName: genericIconName)
                .font(.title2)
                .foregroundStyle(genericIconColor)
        }
    }

    private var genericIconName: String {
        guard let mimeType = file.mimeType else { return "doc" }
        return switch mimeType {
        case let m where m.contains("pdf"): "doc.richtext"
        case let m where m.contains("image"): "photo"
        case let m where m.contains("video"): "film"
        case let m where m.contains("audio"): "music.note"
        case let m where m.contains("zip") || m.contains("compressed"): "doc.zipper"
        case let m where m.contains("text"): "doc.plaintext"
        default: "doc"
        }
    }

    private var genericIconColor: Color {
        guard let mimeType = file.mimeType else { return .secondary }
        return switch mimeType {
        case let m where m.contains("pdf"): .red
        case let m where m.contains("image"): .purple
        default: .secondary
        }
    }
}
