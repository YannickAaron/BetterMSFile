import SwiftUI

struct SearchResultsView: View {
    let viewModel: SearchViewModel
    @Binding var selectedFileId: String?
    @FocusState.Binding var isSearchFieldFocused: Bool
    var onJumpToLocation: (UnifiedFile) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Search bar + filters
            searchBar
            filterBar

            Divider()

            // Results
            if viewModel.query.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("Search across all your files")
                        .foregroundStyle(.secondary)
                    Text("OneDrive, SharePoint, and Teams")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.isSearching && viewModel.results.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Searching...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(error)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.results.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.questionmark")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No files match \"\(viewModel.query)\"")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ZStack(alignment: .top) {
                    List(viewModel.results, id: \.uniqueId, selection: $selectedFileId) { file in
                        FileRowView(file: file)
                            .tag(file.uniqueId)
                    }
                    .contextMenu(forSelectionType: String.self) { ids in
                        if let id = ids.first,
                           let file = viewModel.results.first(where: { $0.uniqueId == id }) {
                            contextMenuItems(for: file)
                        }
                    } primaryAction: { ids in
                        if let id = ids.first,
                           let file = viewModel.results.first(where: { $0.uniqueId == id }) {
                            if let url = URL(string: file.webURL) {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }

                    if viewModel.isSearching {
                        ProgressView()
                            .controlSize(.small)
                            .padding(6)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .padding(4)
                    }
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search files...", text: Bindable(viewModel).query)
                .textFieldStyle(.plain)
                .focused($isSearchFieldFocused)

            if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 8) {
            Picker("Type", selection: Bindable(viewModel).fileTypeFilter) {
                Text("Any Type").tag(nil as String?)
                Divider()
                Text("Documents").tag("docx" as String?)
                Text("Spreadsheets").tag("xlsx" as String?)
                Text("Presentations").tag("pptx" as String?)
                Text("PDFs").tag("pdf" as String?)
                Text("Images").tag("png" as String?)
            }
            .pickerStyle(.menu)
            .fixedSize()
            .onChange(of: viewModel.fileTypeFilter) { _, _ in
                viewModel.searchNow()
            }

            Spacer()

            if viewModel.fileTypeFilter != nil {
                Button("Clear Filters") {
                    viewModel.clearFilters()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)
            }

            Text("\(viewModel.results.count) results")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuItems(for file: UnifiedFile) -> some View {
        if let msIcon = MSAppIcon.forFile(mimeType: file.mimeType, fileName: file.name),
           MSAppIcon.isNativeAppAvailable(for: file) {
            Button("Open in \(msIcon.appName)") {
                MSAppIcon.openInNativeApp(file: file)
            }
        }

        Button("Open in Browser") {
            if let url = URL(string: file.webURL) {
                NSWorkspace.shared.open(url)
            }
        }

        Button("Show in Folder") {
            onJumpToLocation(file)
        }

        Divider()

        Button("Copy Link") {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(file.webURL, forType: .string)
        }
    }
}
