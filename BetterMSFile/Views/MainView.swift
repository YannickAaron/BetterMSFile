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
    @State private var selectedFileIds: Set<String> = []
    @State private var showInspector = false
    @State private var isSearching = false
    @State private var fileListVM: FileListViewModel
    @State private var sidebarVM: SidebarViewModel
    @State private var searchVM: SearchViewModel
    @State private var favoritesVM = FavoritesViewModel()
    @State private var frecencyVM = FrecencyViewModel()
    @State private var loadContentTask: Task<Void, Never>?
    @FocusState private var isSearchFieldFocused: Bool
    @State private var tabs: [FileTab] = [FileTab(name: "My Files", breadcrumbs: [], cacheKey: nil)]
    @State private var activeTabId: UUID?

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
                    selectedFileIds: $selectedFileIds,
                    isSearchFieldFocused: $isSearchFieldFocused,
                    favoritesVM: favoritesVM,
                    frecencyVM: frecencyVM,
                    availableScopes: sidebarVM.sites.map { .site(id: $0.id, name: $0.displayName) },
                    onJumpToLocation: jumpToLocation
                )
                .navigationTitle("Search")
            } else {
                VStack(spacing: 0) {
                    if tabs.count > 1 {
                        FileTabBarView(
                            tabs: $tabs,
                            activeTabId: $activeTabId,
                            onSelect: { tab in switchToTab(tab) },
                            onClose: { tab in closeTab(tab) }
                        )
                    }
                    FileListView(viewModel: fileListVM, selectedFileIds: $selectedFileIds, favoritesVM: favoritesVM, frecencyVM: frecencyVM)
                }
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
                    if let item = selectedItem {
                        loadContentTask?.cancel()
                        loadContentTask = Task { await loadContent(for: item) }
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(isSearching)
            }

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
            favoritesVM.setModelContext(modelContext)
            frecencyVM.setModelContext(modelContext)
            favoritesVM.loadFavorites()
            frecencyVM.loadSuggestions()
            frecencyVM.pruneStaleRecords()
            if activeTabId == nil { activeTabId = tabs.first?.id }
            await loadContent(for: .myFiles)
        }
        .task {
            await sidebarVM.loadSites()
        }
        .onChange(of: selectedItem) { _, newValue in
            if let item = newValue {
                if isSearching { dismissSearch() }
                // Cancel any in-flight content load to prevent stale results
                loadContentTask?.cancel()
                loadContentTask = Task {
                    selectedFileIds = []
                    await loadContent(for: item)
                }
            }
        }
        .onChange(of: selectedFileIds) { _, newValue in
            if !newValue.isEmpty {
                showInspector = true
            }
        }
        .onChange(of: fileListVM.breadcrumbs.count) { _, _ in
            // Keep active tab name in sync with navigation
            if let activeId = activeTabId,
               let index = tabs.firstIndex(where: { $0.id == activeId }) {
                tabs[index].name = fileListVM.breadcrumbs.last?.name ?? "My Files"
                tabs[index].breadcrumbs = fileListVM.breadcrumbs
                tabs[index].cacheKey = fileListVM.currentCacheKey
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .activateSearch)) { _ in
            activateSearch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleFavorite)) { _ in
            if let id = selectedFileIds.first,
               let file = fileListVM.files.first(where: { $0.uniqueId == id })
                ?? searchVM.results.first(where: { $0.uniqueId == id }) {
                favoritesVM.toggleFavorite(for: file)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateBack)) { _ in
            if isSearching {
                dismissSearch()
            } else {
                Task { await fileListVM.navigateBack() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openInNewTab)) { notification in
            if let file = notification.object as? UnifiedFile, file.isFolder {
                openFolderInNewTab(file)
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
        selectedFileIds = []
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
            selectedFileIds = [file.uniqueId]
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
                Label {
                    Text("OneDrive")
                } icon: {
                    MSAppIcon.oneDrive.icon(size: 16)
                }
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
                } else if let error = sidebarVM.sitesErrorMessage {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Failed to load sites")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Text(error)
                            .foregroundStyle(.tertiary)
                            .font(.caption2)
                        Button("Retry") {
                            Task { await sidebarVM.loadSites() }
                        }
                        .font(.caption)
                    }
                } else if sidebarVM.sites.isEmpty {
                    Text("No teams or sites found")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else {
                    ForEach(sidebarVM.sites) { site in
                        Label {
                            Text(site.displayName)
                        } icon: {
                            MSAppIcon.teams.icon(size: 16)
                        }
                        .tag(SidebarItem.sharePointSite(site))
                    }
                }
            }

            if appState.updateService.updateAvailable {
                Section {
                    Button {
                        if let url = appState.updateService.downloadURL {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label("Update Available", systemImage: "arrow.down.circle")
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }

        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) {
            VStack(alignment: .leading, spacing: 0) {
                if !favoritesVM.favorites.isEmpty {
                    sidebarSection("Favorites") {
                        ForEach(favoritesVM.favorites) { fav in
                            sidebarButton(label: fav.name, icon: fav.isFolder ? "folder.fill" : "star.fill") {
                                let file = fav.toUnifiedFile()
                                selectedItem = nil
                                if file.isFolder {
                                    Task { await fileListVM.navigateIntoFolder(file) }
                                } else {
                                    dismissSearch()
                                    Task {
                                        await fileListVM.navigateToFile(file)
                                        selectedFileIds = [file.uniqueId]
                                    }
                                }
                            }
                            .contextMenu {
                                Button("Remove from Favorites") {
                                    favoritesVM.toggleFavorite(for: fav.toUnifiedFile())
                                }
                            }
                        }
                    }
                }

                if !frecencyVM.suggestions.isEmpty {
                    sidebarSection("Frequently Used") {
                        ForEach(frecencyVM.suggestions) { record in
                            sidebarButton(label: record.name, icon: record.isFolder ? "folder.fill" : "clock.arrow.circlepath") {
                                let file = record.toUnifiedFile()
                                selectedItem = nil
                                if file.isFolder {
                                    Task { await fileListVM.navigateIntoFolder(file) }
                                } else {
                                    dismissSearch()
                                    Task {
                                        await fileListVM.navigateToFile(file)
                                        selectedFileIds = [file.uniqueId]
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(.bar)
        }
        .navigationTitle("BetterMSFile")
    }

    // MARK: - Sidebar Helpers

    private func sidebarSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 2)
            content()
        }
    }

    private func sidebarButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    // MARK: - Inspector

    @ViewBuilder
    private var inspectorContent: some View {
        if selectedFileIds.count > 1 {
            let selectedFiles = selectedFileIds.compactMap { id in
                fileListVM.files.first(where: { $0.uniqueId == id })
                    ?? searchVM.results.first(where: { $0.uniqueId == id })
            }
            let totalSize = selectedFiles.filter { !$0.isFolder }.reduce(Int64(0)) { $0 + $1.size }
            let folderCount = selectedFiles.filter { $0.isFolder }.count
            let fileCount = selectedFiles.count - folderCount

            VStack(spacing: 12) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("\(selectedFileIds.count) items selected")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    if folderCount > 0 {
                        Text("\(folderCount) folder\(folderCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    if fileCount > 0 {
                        Text("\(fileCount) file\(fileCount == 1 ? "" : "s") — \(totalSize.formattedFileSize)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        } else if let id = selectedFileIds.first {
            let file = fileListVM.files.first(where: { $0.uniqueId == id })
                ?? searchVM.results.first(where: { $0.uniqueId == id })
            if let file {
                FileDetailView(
                    file: file,
                    favoritesVM: favoritesVM,
                    fileService: appState.fileService,
                    onShowInFolder: isSearching ? { jumpToLocation(file) } : nil,
                    onQuickLook: !file.isFolder ? {
                        NotificationCenter.default.post(name: .quickLookFile, object: file.uniqueId)
                    } : nil
                )
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

    // MARK: - Tabs

    private func switchToTab(_ tab: FileTab) {
        // Save current tab state before switching
        saveCurrentTabState()
        activeTabId = tab.id

        // Restore the tab's location
        if !tab.breadcrumbs.isEmpty {
            // Navigate to the tab's last breadcrumb
            let lastCrumb = tab.breadcrumbs.last!
            selectedFileIds = []
            loadContentTask?.cancel()
            loadContentTask = Task {
                fileListVM.setLoading()
                if let itemId = lastCrumb.itemId {
                    // Restore breadcrumbs and load folder
                    fileListVM.breadcrumbs = tab.breadcrumbs
                    let cacheKey = "folder_\(lastCrumb.driveId)_\(itemId)"
                    await fileListVM.loadFolderDirect(
                        driveId: lastCrumb.driveId,
                        itemId: itemId,
                        source: lastCrumb.source,
                        cacheKey: cacheKey
                    )
                } else {
                    // Root level
                    switch lastCrumb.source {
                    case .oneDrive:
                        selectedItem = .myFiles
                        await fileListVM.loadMyDriveRoot()
                    case .shared:
                        selectedItem = .shared
                        await fileListVM.loadSharedWithMe()
                    case .sharePoint:
                        await fileListVM.loadDriveRoot(driveId: lastCrumb.driveId, source: lastCrumb.source)
                    }
                }
            }
        } else {
            // Default: load My Files
            selectedFileIds = []
            loadContentTask?.cancel()
            loadContentTask = Task {
                await loadContent(for: .myFiles)
            }
        }
    }

    private func closeTab(_ tab: FileTab) {
        guard tabs.count > 1 else { return }
        let wasActive = activeTabId == tab.id
        tabs.removeAll { $0.id == tab.id }

        if wasActive {
            let newActive = tabs.first!
            activeTabId = newActive.id
            switchToTab(newActive)
        }
    }

    private func saveCurrentTabState() {
        guard let activeId = activeTabId,
              let index = tabs.firstIndex(where: { $0.id == activeId }) else { return }
        tabs[index].breadcrumbs = fileListVM.breadcrumbs
        tabs[index].cacheKey = fileListVM.currentCacheKey
        tabs[index].name = fileListVM.breadcrumbs.last?.name ?? "My Files"
    }

    func openFolderInNewTab(_ file: UnifiedFile) {
        guard file.isFolder else { return }
        saveCurrentTabState()

        let source = file.source
        let newBreadcrumbs = fileListVM.breadcrumbs + [
            FileListViewModel.BreadcrumbItem(name: file.name, driveId: file.driveId, itemId: file.itemId, source: source)
        ]
        let newTab = FileTab(name: file.name, breadcrumbs: newBreadcrumbs, cacheKey: "folder_\(file.driveId)_\(file.itemId)")
        tabs.append(newTab)
        activeTabId = newTab.id
        switchToTab(newTab)
    }

    // MARK: - Content Loading

    private func loadContent(for item: SidebarItem) async {
        // Signal loading immediately so the UI reflects the switch
        fileListVM.setLoading()

        switch item {
        case .myFiles:
            await fileListVM.loadMyDriveRoot()
        case .recent:
            await fileListVM.loadRecentFiles()
        case .shared:
            await fileListVM.loadSharedWithMe()
        case .sharePointSite(let site):
            if let groupId = site.groupId {
                do {
                    let channels = try await appState.siteService.fetchTeamChannels(
                        teamId: groupId,
                        teamName: site.displayName,
                        siteId: site.id
                    )
                    guard !Task.isCancelled else { return }
                    fileListVM.loadTeamChannels(channels, teamName: site.displayName, siteId: site.id)
                } catch {
                    guard !Task.isCancelled else { return }
                    // Team channels failed — fall back to site drives
                    print("Failed to load channels: \(error.localizedDescription)")
                    fileListVM.loadSiteDrives(site: site)
                }
            } else if site.drives.count == 1, let drive = site.drives.first {
                let source = FileSource.sharePoint(siteName: drive.siteName, siteId: drive.siteId)
                await fileListVM.loadDriveRoot(driveId: drive.id, source: source)
            } else {
                fileListVM.loadSiteDrives(site: site)
            }
        }
    }
}
