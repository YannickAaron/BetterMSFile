import Adwaita
import Foundation

/// Shared models for one signed-in window: the Mac AppState / SidebarViewModel / SearchViewModel plus FolderBrowser.
final class Session {
    let appState = AppState()
    let browser: FolderBrowser
    let sidebar: SidebarViewModel
    let search: SearchViewModel

    init() {
        browser = FolderBrowser(fileService: appState.fileService)
        sidebar = SidebarViewModel(siteService: appState.siteService)
        search = SearchViewModel(searchService: appState.searchService)
    }
}

// MARK: - Login

struct LoginView: View {
    var appState: AppState

    var view: Body {
        observe {
            StatusPage(
                "BetterMSFile",
                icon: .custom(name: "folder-remote-symbolic"),
                description: appState.isLoading
                    ? "Finish signing in in your browser…"
                    : "All your OneDrive, SharePoint and Teams files in one place."
            ) {
                VStack {
                    Button("Sign in with Microsoft") {
                        Task { await appState.signIn() }
                    }
                    .suggested()
                    .pill()
                    .insensitive(appState.isLoading)
                    .frame(maxWidth: 260)
                    if let error = appState.errorMessage {
                        Text(error)
                            .wrap(true)
                            .error()
                            .padding()
                    }
                }
            }
            .topToolbar { HeaderBar.empty() }
        }
    }
}

// MARK: - Main window

struct SidebarItem: Identifiable, Equatable {
    let id: String
    let title: String
    let location: FolderBrowser.Location
}

struct MainView: View {
    var session: Session

    @State private var selection = "onedrive"
    @State private var menuFor = ""          // uniqueId of the row whose action menu is open
    @State private var menuTarget = ""       // uniqueId the menu actions apply to (kept after the menu closes)
    @State private var accountMenu = false
    @State private var target: UnifiedFile?  // file a dialog acts on
    @State private var nameText = ""
    @State private var newFolderDialog = false
    @State private var renameDialog = false
    @State private var deleteDialog = false
    @State private var agentsDialog = false
    @State private var alertText = ""
    @State private var toastText = ""
    @State private var toast = Signal()

    private var browser: FolderBrowser { session.browser }
    private var search: SearchViewModel { session.search }

    var view: Body {
        observe {
            NavigationSplitView {
                sidebar
            } content: {
                content
            }
            .vexpand()
            .toast(toastText, signal: $toast)
            .dialog(visible: $newFolderDialog, title: "New Folder", id: "new-folder", width: 380) {
                nameForm(action: "Create") { name in try await browser.createFolder(named: name) }
            }
            .dialog(visible: $renameDialog, title: "Rename", id: "rename", width: 380) {
                nameForm(action: "Rename") { name in
                    if let target { try await browser.rename(target, to: name) }
                }
            }
            .alertDialog(
                visible: $deleteDialog,
                heading: "Delete “\(target?.name ?? "")”?",
                body: "It goes to the Microsoft 365 recycle bin and can be restored from there.",
                id: "delete" // dialogs on one view share storage keyed by id, so each needs its own
            )
            .response("Cancel", role: .close) { }
            .response("Delete", appearance: .destructive, role: .default) {
                if let target { run { try await browser.delete(target) } }
            }
            .alertDialog(visible: alertVisible, heading: "Something went wrong", body: alertText, id: "error")
            .response("OK", role: .close) { }
            .dialog(visible: $agentsDialog, title: "AI Agents", id: "agents", width: 460) {
                AgentsView()
                    .topToolbar { HeaderBar.empty() }
            }
            .onAppear {
                // Same startup as the Mac MainView: sites for the sidebar, OneDrive in the content.
                Task { await session.sidebar.loadSites() }
                browser.show(.myDrive)
            }
        }
    }

    // MARK: Sidebar

    private var sidebarItems: [SidebarItem] {
        var items = [
            SidebarItem(id: "onedrive", title: "OneDrive", location: .myDrive),
            SidebarItem(id: "recent", title: "Recent", location: .recent),
            SidebarItem(id: "shared", title: "Shared with Me", location: .shared),
        ]
        for site in session.sidebar.sites {
            for drive in site.drives {
                let title = site.drives.count > 1 ? "\(site.displayName) – \(drive.name)" : site.displayName
                items.append(SidebarItem(
                    id: "drive:\(drive.id)",
                    title: title,
                    location: .driveRoot(driveId: drive.id, name: title,
                                         source: .sharePoint(siteName: site.displayName, siteId: site.id))
                ))
            }
        }
        return items
    }

    private var sidebarSelection: Binding<String> {
        .init {
            selection
        } set: { id in
            guard id != selection, let item = sidebarItems.first(where: { $0.id == id }) else { return }
            selection = id
            search.reset()
            browser.show(item.location)
        }
    }

    @ViewBuilder private var sidebar: Body {
        ScrollView {
            VStack {
            List(sidebarItems, selection: sidebarSelection) { item in
                Text(item.title)
                    .ellipsize()
                    .halign(.start)
                    .padding(8)
            }
            .sidebarStyle()
            if session.sidebar.isLoadingSites {
                Spinner().padding()
            } else if let error = session.sidebar.sitesErrorMessage {
                VStack {
                    Text("Couldn't load sites and Teams: \(error)")
                        .wrap(true)
                        .caption()
                    Button("Retry") { Task { await session.sidebar.loadSites() } }
                        .padding()
                }
                .padding()
            }
            }
        }
        .hscrollbarPolicy(.never)
        .topToolbar {
            HeaderBar.end {
                Button(icon: .default(icon: .openMenu)) { accountMenu = true }
                    .tooltip("Account")
                    .menuPopover(visible: $accountMenu) {
                        MenuSection {
                            MenuButton("AI Agents…") { agentsDialog = true }
                        }
                        MenuSection {
                            MenuButton("Sign Out \(session.appState.userEmail ?? "")") {
                                Task { await session.appState.signOut() }
                            }
                        }
                    }
            }
            .headerBarTitle { WindowTitle(subtitle: session.appState.userName ?? "", title: "BetterMSFile") }
        }
    }

    // MARK: Content

    private var isSearching: Bool { !search.query.trimmingCharacters(in: .whitespaces).isEmpty }

    @ViewBuilder private var content: Body {
        VStack {
            Entry("Search OneDrive, SharePoint and Teams", text: .init { search.query } set: { search.query = $0 })
                .padding(12)
            ScrollView {
                if isSearching {
                    fileList(search.results, loading: search.isSearching, error: search.errorMessage,
                             empty: "No results")
                } else {
                    fileList(browser.files, loading: browser.isLoading, error: browser.errorMessage,
                             empty: "This folder is empty")
                }
            }
            .vexpand()
        }
        .topToolbar {
            HeaderBar {
                Button(icon: .default(icon: .goPrevious)) { browser.goBack() }
                    .tooltip("Back")
                    .insensitive(!browser.canGoBack || isSearching)
            } end: {
                Button(icon: .default(icon: .folderNew)) {
                    nameText = ""
                    newFolderDialog = true
                }
                .tooltip("New Folder")
                .insensitive(browser.folderTarget == nil || isSearching)
                Button(icon: .default(icon: .viewRefresh)) { browser.reload() }
                    .tooltip("Refresh")
            }
            .headerBarTitle {
                WindowTitle(subtitle: isSearching ? "" : browser.breadcrumb,
                            title: isSearching ? "Search" : browser.current.title)
            }
        }
    }

    @ViewBuilder
    private func fileList(_ files: [UnifiedFile], loading: Bool, error: String?, empty: String) -> Body {
        if loading && files.isEmpty {
            Spinner().padding(40)
        } else if let error {
            StatusPage("Couldn't load files", icon: .custom(name: "dialog-warning-symbolic"), description: error) {
                Button("Retry") { isSearching ? search.searchNow() : browser.reload() }.pill().frame(maxWidth: 160)
            }
        } else if files.isEmpty {
            StatusPage(empty, icon: .custom(name: "folder-symbolic"))
        } else {
            List(files, id: \.uniqueId, selection: nil) { file in
                row(file)
            }
            .boxedList()
            .valign(.start)
            .padding(12)
        }
    }

    private func row(_ file: UnifiedFile) -> AnyView {
        ActionRow(file.name)
            .subtitle(details(file))
            .prefix {
                Image().iconName(file.isFolder ? "folder-symbolic" : "text-x-generic-symbolic").padding(4)
            }
            .suffix {
                if !file.isFolder {
                    Button(icon: .default(icon: .documentOpen)) { run { try await browser.openLocally(file) } }
                        .flat()
                        .valign(.center)
                        .tooltip("Open")
                }
                Button(icon: .custom(name: "view-more-symbolic")) {
                    menuFor = file.uniqueId
                    menuTarget = file.uniqueId
                }
                    .flat()
                    .valign(.center)
                    .tooltip("More")
                    .menuPopover(visible: .init { menuFor == file.uniqueId } set: { menuFor = $0 ? file.uniqueId : "" }) {
                        actions(file)
                    }
            }
            .onClick {
                // ponytail: click gesture, since AdwActionRow rows aren't activatable without an activatable widget
                guard file.isFolder else { return }
                search.reset()
                browser.open(file)
            }
    }

    /// The file the row menu was opened for. Menu actions look it up instead of capturing `file`:
    /// MenuButton registers one app action per label, so every row's "Rename…" shares one handler.
    private var menuFile: UnifiedFile? {
        (isSearching ? search.results : browser.files).first { $0.uniqueId == menuTarget }
    }

    @ViewBuilder
    private func actions(_ file: UnifiedFile) -> Body {
        MenuSection {
            if !file.isFolder {
                MenuButton("Download") {
                    guard let file = menuFile else { return }
                    run {
                        let url = try await browser.download(file)
                        toastText = "Downloaded to \(url.path)"
                        toast.signal()
                    }
                }
            }
            MenuButton("Open in Browser") {
                guard let file = menuFile else { return }
                run { try Desktop.open(file.webURL) }
            }
            MenuButton("Copy Link") {
                guard let file = menuFile else { return }
                AdwaitaApp.copy(file.webURL)
                toastText = "Link copied"
                toast.signal()
            }
        }
        MenuSection {
            MenuButton("Rename…") {
                guard let file = menuFile else { return }
                target = file
                nameText = file.name
                renameDialog = true
            }
            MenuButton("Delete…") {
                guard let file = menuFile else { return }
                target = file
                deleteDialog = true
            }
        }
    }

    private func nameForm(action: String, perform: @escaping (String) async throws -> Void) -> Body {
        let submit = {
            let name = nameText
            newFolderDialog = false
            renameDialog = false
            run { try await perform(name) }
        }
        return [
            VStack {
                Form {
                    EntryRow("Name", text: $nameText).entryActivated(submit) // Return key
                }
                .padding(16)
                Button(action, handler: submit)
                    .suggested()
                    .pill()
                    .halign(.center)
                    .padding(16)
            }
            .topToolbar { HeaderBar.empty() },
        ]
    }

    private func details(_ file: UnifiedFile) -> String {
        var parts = [file.modifiedAt.relativeFormatted]
        if let by = file.modifiedBy { parts.append(by) }
        if !file.isFolder { parts.append(file.size.formattedFileSize) }
        return parts.joined(separator: " · ")
    }

    private var alertVisible: Binding<Bool> {
        .init { !alertText.isEmpty } set: { if !$0 { alertText = "" } }
    }

    /// Runs a file action; failures show an alert (never fail silently).
    private func run(_ action: @escaping () async throws -> Void) {
        Task {
            do {
                try await action()
            } catch {
                alertText = error.localizedDescription
            }
        }
    }
}

// MARK: - Agents (Mac: Settings → Agents)

struct AgentsView: View {
    @State private var level = AgentAccess.level
    @State private var copied = false

    private let command = "claude mcp add bettermsfile -- bettermsfile --mcp"

    var view: Body {
        VStack {
            Text("Let AI agents (Claude Code, Cursor and other MCP clients) use your Microsoft 365 files.")
                .wrap(true)
                .padding(16)
            Form {
                SwitchRow("Allow agents to read files", isOn: .init { level != "off" } set: { on in
                    level = on ? "read" : "off"
                    AgentAccess.set(level)
                })
                SwitchRow("Allow agents to change files", isOn: .init { level == "write" } set: { on in
                    level = on ? "write" : (level == "off" ? "off" : "read")
                    AgentAccess.set(level)
                })
                .insensitive(level == "off")
                ActionRow("Add to Claude Code")
                    .subtitle(command)
                    .suffix {
                        Button(icon: .default(icon: .editCopy)) {
                            AdwaitaApp.copy(command)
                            copied = true
                        }
                        .flat()
                        .valign(.center)
                        .tooltip(copied ? "Copied" : "Copy")
                    }
            }
            .padding(16)
        }
    }
}
