import SwiftUI
import SwiftData

enum SidebarItem: Hashable {
    case myFiles
    case recent
    case shared
    case sharePointSite(SharePointSite)

    var title: String {
        switch self {
        case .myFiles: "My Files"
        case .recent: "Recent"
        case .shared: "Shared with Me"
        case .sharePointSite(let site): site.displayName
        }
    }

    var icon: String {
        switch self {
        case .myFiles: "externaldrive"
        case .recent: "clock"
        case .shared: "person.2"
        case .sharePointSite: "building.2"
        }
    }
}

struct MainView: View {
    let appState: AppState
    @Environment(\.modelContext) private var modelContext
    @State private var selectedItem: SidebarItem? = .myFiles
    @State private var selectedFileId: String?
    @State private var showInspector = false
    @State private var isSearching = false
    @State private var fileListVM: FileListViewModel
    @State private var sidebarVM: SidebarViewModel
    @State private var searchVM: SearchViewModel
    @FocusState private var isSearchFieldFocused: Bool

    init(appState: AppState) {
        self.appState = appState
        self._fileListVM = State(initialValue: FileListViewModel(fileService: appState.fileService))
        self._sidebarVM = State(initialValue: SidebarViewModel(siteService: appState.siteService))
        self._searchVM = State(initialValue: SearchViewModel(searchService: appState.searchService))
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            if isSearching {
                SearchResultsView(
                    viewModel: searchVM,
                    selectedFileId: $selectedFileId,
                    isSearchFieldFocused: $isSearchFieldFocused,
                    onJumpToLocation: jumpToLocation
                )
                .navigationTitle("Search")
            } else {
                FileListView(viewModel: fileListVM, selectedFileId: $selectedFileId)
                    .navigationTitle(selectedItem?.title ?? "Files")
            }
        }
        .inspector(isPresented: $showInspector) {
            inspectorContent
                .inspectorColumnWidth(min: 200, ideal: 260, max: 350)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    toggleSearch()
                } label: {
                    Label("Search", systemImage: isSearching ? "xmark" : "magnifyingglass")
                }
                .keyboardShortcut("k", modifiers: .command)
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    showInspector.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.right")
                }
                .keyboardShortcut("i", modifiers: .command)
            }

            ToolbarItem(placement: .automatic) {
                if let name = appState.userName {
                    Menu {
                        Text(appState.userEmail ?? "")
                        Divider()
                        Button("Sign Out") {
                            Task { await appState.signOut() }
                        }
                    } label: {
                        Label(name, systemImage: "person.circle")
                    }
                }
            }
        }
        .task {
            fileListVM.setModelContext(modelContext)
            await sidebarVM.loadSites()
            await loadContent(for: .myFiles)
        }
        .onChange(of: selectedItem) { _, newValue in
            if let item = newValue {
                if isSearching { dismissSearch() }
                Task {
                    selectedFileId = nil
                    await loadContent(for: item)
                }
            }
        }
        .onChange(of: selectedFileId) { _, newValue in
            if newValue != nil {
                showInspector = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .activateSearch)) { _ in
            activateSearch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateBack)) { _ in
            if isSearching {
                dismissSearch()
            } else {
                Task { await fileListVM.navigateBack() }
            }
        }
        .onKeyPress(.escape) {
            if isSearching {
                dismissSearch()
                return .handled
            }
            return .ignored
        }
    }

    // MARK: - Search

    private func toggleSearch() {
        if isSearching {
            dismissSearch()
        } else {
            activateSearch()
        }
    }

    private func activateSearch() {
        selectedFileId = nil
        searchVM.reset()
        isSearching = true
        isSearchFieldFocused = true
    }

    private func dismissSearch() {
        isSearching = false
        isSearchFieldFocused = false
        searchVM.reset()
    }

    private func jumpToLocation(_ file: UnifiedFile) {
        dismissSearch()
        Task {
            await fileListVM.navigateToFile(file)
            selectedFileId = file.uniqueId
            // Update sidebar to match the file's source
            switch file.source {
            case .oneDrive:
                selectedItem = .myFiles
            case .shared:
                selectedItem = .shared
            case .sharePoint:
                break // Keep current sidebar selection
            }
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebar: some View {
        List(selection: $selectedItem) {
            Section("Locations") {
                Label("OneDrive", systemImage: "externaldrive")
                    .tag(SidebarItem.myFiles)
                Label("Recent", systemImage: "clock")
                    .tag(SidebarItem.recent)
                Label("Shared with Me", systemImage: "person.2")
                    .tag(SidebarItem.shared)
            }

            Section("Teams & Sites") {
                if sidebarVM.isLoadingSites {
                    ProgressView()
                        .controlSize(.small)
                } else if sidebarVM.sites.isEmpty {
                    Text("No teams or sites found")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    ForEach(sidebarVM.sites) { site in
                        Label(site.displayName, systemImage: "building.2")
                            .tag(SidebarItem.sharePointSite(site))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("BetterMSFile")
    }

    // MARK: - Inspector

    @ViewBuilder
    private var inspectorContent: some View {
        if let id = selectedFileId {
            // Look in both file list and search results
            let file = fileListVM.files.first(where: { $0.uniqueId == id })
                ?? searchVM.results.first(where: { $0.uniqueId == id })
            if let file {
                FileDetailView(file: file, onShowInFolder: isSearching ? { jumpToLocation(file) } : nil)
            } else {
                Text("No Selection")
                    .foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity)
            }
        } else {
            Text("No Selection")
                .foregroundStyle(.secondary)
                .frame(maxHeight: .infinity)
        }
    }

    // MARK: - Content Loading

    private func loadContent(for item: SidebarItem) async {
        switch item {
        case .myFiles:
            await fileListVM.loadMyDriveRoot()
        case .recent:
            await fileListVM.loadRecentFiles()
        case .shared:
            await fileListVM.loadSharedWithMe()
        case .sharePointSite(let site):
            if let groupId = site.groupId {
                fileListVM.setLoading()
                do {
                    let channels = try await appState.siteService.fetchTeamChannels(
                        teamId: groupId,
                        teamName: site.displayName,
                        siteId: site.id
                    )
                    await fileListVM.loadTeamChannels(channels, teamName: site.displayName, siteId: site.id)
                } catch {
                    print("Failed to load channels: \(error.localizedDescription)")
                    await fileListVM.loadSiteDrives(site: site)
                }
            } else if site.drives.count == 1, let drive = site.drives.first {
                let source = FileSource.sharePoint(siteName: drive.siteName, siteId: drive.siteId)
                await fileListVM.loadDriveRoot(driveId: drive.id, source: source)
            } else {
                await fileListVM.loadSiteDrives(site: site)
            }
        }
    }
}
