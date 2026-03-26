import SwiftUI

struct SearchResultsView: View {
    let viewModel: SearchViewModel
    @Binding var selectedFileIds: Set<String>
    @FocusState.Binding var isSearchFieldFocused: Bool
    var favoritesVM: FavoritesViewModel?
    var frecencyVM: FrecencyViewModel?
    var availableScopes: [SearchScope] = []
    var onJumpToLocation: (UnifiedFile) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Search bar + filters
            searchBar
            filterBar

            Divider()

            // Results
            if viewModel.query.count < 2 {
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
                    Button("Retry") { viewModel.searchNow() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
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
                    List(selection: $selectedFileIds) {
                        ForEach(viewModel.results, id: \.uniqueId) { file in
                            FileRowView(file: file)
                                .tag(file.uniqueId)
                        }

                        // Load More button
                        if viewModel.hasMoreResults {
                            HStack {
                                Spacer()
                                if viewModel.isLoadingMore {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Loading more...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Button {
                                        Task { await viewModel.loadMore() }
                                    } label: {
                                        Label("Load More Results", systemImage: "arrow.down.circle")
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .listRowSeparator(.hidden)
                        }
                    }
                    .contextMenu(forSelectionType: String.self) { ids in
                        if let id = ids.first,
                           let file = viewModel.results.first(where: { $0.uniqueId == id }) {
                            contextMenuItems(for: file)
                        }
                    } primaryAction: { ids in
                        if let id = ids.first,
                           let file = viewModel.results.first(where: { $0.uniqueId == id }) {
                            frecencyVM?.recordAccess(for: file)
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

            TextField(viewModel.scope == .all ? "Search files..." : "Search in \(viewModel.scope.displayName)...", text: Bindable(viewModel).query)
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
            // Scope picker
            Picker("Scope", selection: Bindable(viewModel).scope) {
                Text("All Files").tag(SearchScope.all)
                Text("My OneDrive").tag(SearchScope.myOneDrive)
                if !availableScopes.isEmpty {
                    Divider()
                    ForEach(availableScopes, id: \.self) { scope in
                        Text(scope.displayName).tag(scope)
                    }
                }
            }
            .pickerStyle(.menu)
            .fixedSize()

            // File type filter
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

            // Date filter
            Picker("Date", selection: Bindable(viewModel).dateFilterPreset) {
                ForEach(DateFilterPreset.allCases, id: \.self) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()

            Spacer()

            if hasActiveFilters {
                Button("Clear Filters") {
                    viewModel.clearFilters()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)
            }

            // Result count
            if let total = viewModel.totalResults {
                Text("\(viewModel.results.count) of \(total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !viewModel.results.isEmpty {
                Text("\(viewModel.results.count) results")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private var hasActiveFilters: Bool {
        viewModel.fileTypeFilter != nil || viewModel.dateFilterPreset != .anyTime || viewModel.scope != .all
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

        if let favoritesVM {
            Divider()
            Button(favoritesVM.isFavorite(file) ? "Remove from Favorites" : "Add to Favorites") {
                favoritesVM.toggleFavorite(for: file)
            }
        }
    }
}
