import SwiftUI

struct FileGridCellView: View {
    let file: UnifiedFile

    var body: some View {
        VStack(spacing: 6) {
            thumbnailView
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )

            Text(file.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 120)

            sourceBadge
        }
        .padding(8)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if file.isFolder {
            Image(systemName: "folder.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.blue.opacity(0.05))
        } else if let thumbnailURL = file.thumbnailURL, let url = URL(string: thumbnailURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    fileTypeIcon
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                @unknown default:
                    fileTypeIcon
                }
            }
        } else {
            fileTypeIcon
        }
    }

    @ViewBuilder
    private var fileTypeIcon: some View {
        if let msIcon = MSAppIcon.forFile(mimeType: file.mimeType, fileName: file.name) {
            msIcon.icon(size: 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.secondary.opacity(0.05))
        } else {
            Image(systemName: iconName)
                .font(.system(size: 36))
                .foregroundStyle(iconColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.secondary.opacity(0.05))
        }
    }

    @ViewBuilder
    private var sourceBadge: some View {
        if case .sharePoint(let siteName, _) = file.source {
            Text(siteName)
                .font(.caption2)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(.quaternary)
                .clipShape(Capsule())
        }
    }

    private var iconName: String {
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

    private var iconColor: Color {
        guard let mimeType = file.mimeType else { return .secondary }
        return switch mimeType {
        case let m where m.contains("pdf"): .red
        case let m where m.contains("image"): .purple
        default: .secondary
        }
    }
}
