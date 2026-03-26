import SwiftUI

struct FileDetailView: View {
    let file: UnifiedFile
    var favoritesVM: FavoritesViewModel?
    var onShowInFolder: (() -> Void)?
    @State private var showCopiedFeedback = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Thumbnail preview
                if let thumbnailURL = file.thumbnailURL, let url = URL(string: thumbnailURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                        case .failure:
                            fileIcon
                        default:
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 80)
                        }
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    fileIcon
                }

                // Name
                Text(file.name)
                    .font(.title3)
                    .fontWeight(.medium)
                    .lineLimit(3)

                Divider()

                // Metadata
                Group {
                    if !file.isFolder {
                        detailRow("Size", value: file.size.formattedFileSize)
                    }
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
                    // Favorite toggle
                    if let favoritesVM {
                        let isFav = favoritesVM.isFavorite(file)
                        Button {
                            favoritesVM.toggleFavorite(for: file)
                        } label: {
                            Label(isFav ? "Remove from Favorites" : "Add to Favorites",
                                  systemImage: isFav ? "star.fill" : "star")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    // Open in native app (if applicable)
                    if let msIcon = MSAppIcon.forFile(mimeType: file.mimeType, fileName: file.name),
                       MSAppIcon.isNativeAppAvailable(for: file) {
                        Button {
                            MSAppIcon.openInNativeApp(file: file)
                        } label: {
                            HStack {
                                msIcon.icon(size: 16)
                                Text("Open in \(msIcon.appName)")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Button {
                        if let url = URL(string: file.webURL) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label("Open in Browser", systemImage: "safari")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        copyLink()
                    } label: {
                        Label(showCopiedFeedback ? "Copied!" : "Copy Link", systemImage: showCopiedFeedback ? "checkmark" : "link")
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
            }
            .padding()
        }
        .frame(minWidth: 200)
    }

    // MARK: - File Icon (fallback when no thumbnail)

    private var fileIcon: some View {
        HStack {
            Spacer()
            if file.isFolder {
                Image(systemName: "folder.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
            } else if let msIcon = MSAppIcon.forFile(mimeType: file.mimeType, fileName: file.name) {
                msIcon.icon(size: 48)
            } else {
                Image(systemName: iconName)
                    .font(.system(size: 48))
                    .foregroundStyle(iconColor)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Copy Link

    private func copyLink() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(file.webURL, forType: .string)

        showCopiedFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopiedFeedback = false
        }
    }

    // MARK: - Helpers

    private var iconName: String {
        guard let mimeType = file.mimeType else { return "doc" }
        return switch mimeType {
        case let m where m.contains("pdf"): "doc.richtext"
        case let m where m.contains("word") || m.contains("document"): "doc.text"
        case let m where m.contains("spreadsheet") || m.contains("excel"): "tablecells"
        case let m where m.contains("presentation") || m.contains("powerpoint"): "rectangle.stack"
        case let m where m.contains("image"): "photo"
        case let m where m.contains("video"): "film"
        case let m where m.contains("audio"): "music.note"
        default: "doc"
        }
    }

    private var iconColor: Color {
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
