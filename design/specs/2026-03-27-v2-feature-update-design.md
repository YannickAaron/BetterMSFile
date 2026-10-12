# BetterMSFile v2.0 — Feature Update Design Spec

**Date:** 2026-03-27
**Status:** Approved
**Scope:** 7 medium features for a major update

## Context

BetterMSFile is a native macOS file browser for Microsoft 365 (OneDrive, SharePoint, Teams). The current release (v1.65) provides solid browsing, search, favorites, frecency, drag-and-drop move/reorder, Quick Look, and downloads across a three-column NavigationSplitView layout.

This update addresses two functional gaps (upload, rename), adds four power-user features (grid view, tabs, version history, enhanced preview), and wraps everything in a UI polish pass. The goal is to transform BetterMSFile from a read-only file browser into a full two-way file manager that attracts new users, fixes pain points, and deepens the experience for power users.

## Architecture Overview

All 7 features follow the existing MVVM + service layer pattern:

```
SwiftUI Views -> ViewModels -> Services -> GraphClient -> Microsoft Graph API
```

- All new API calls go through `GraphClient` (never raw URLSession)
- All ViewModels are `@MainActor`
- All user-visible failures show alert dialogs
- Task cancellation on navigation changes applies to all new async work

---

## Feature 1: File Upload (Drag + Button)

### Goal
Let users add files to any writable folder via drag-from-Finder or an upload button.

### API Design

**Simple upload (<4MB):**
```
PUT /drives/{driveId}/items/{parentId}:/{filename}:/content
```

**Resumable upload (>=4MB):**
```
POST /drives/{driveId}/items/{parentId}:/{filename}:/createUploadSession
```
Then upload in 320KB-10MB chunks with byte-range headers and progress tracking.

**Conflict resolution:** Set `@microsoft.graph.conflictBehavior` to `rename` or `replace` based on user dialog choice.

### UI Specification

- **Drop zone:** File list area accepts `.fileURL` drag items from Finder. On drag-enter, show a dashed-border highlight overlay with "Drop to upload" label. Supports multiple files.
- **Upload button:** Toolbar button (SF Symbol: `arrow.up.doc`) opens `NSOpenPanel` with `allowsMultipleSelection = true`.
- **Progress overlay:** Floating panel (similar to existing download progress) showing:
  - Per-file row: filename, progress bar, percentage, cancel button
  - Overall: "Uploading X of Y files"
- **Conflict dialog:** When a file with the same name exists: "Replace" / "Keep Both" (appends counter) / "Skip"
- **Read-only guard:** Disable drop zone and upload button for read-only locations. Tooltip: "You don't have permission to upload here."

### Architecture

- **Modify:** `Networking/GraphClient.swift` — add a new `put(url:data:contentType:)` method for raw data uploads (the existing client only has `get`/`post`/`patch`/`delete` with JSON encoding; simple upload requires `PUT` with raw `Data` body and `Content-Type` header from the file). Also add `createUploadSession()` and `uploadChunk()` methods.
- **Modify:** `Services/FileService.swift` — add upload methods to the existing file service (following the same pattern as `createFolder`, `deleteItems`, `moveFile`, `downloadFile`). `FileService` already holds a `GraphClient` reference and is injected via `AppState`. Upload methods: `uploadSmall(data:filename:parentDriveId:parentItemId:conflictBehavior:)`, `createUploadSession(...)`, `uploadChunk(sessionUrl:range:data:)`.
- **Modify:** `ViewModels/FileListViewModel.swift` — add `uploadFiles(_ urls: [URL])` and `cancelUpload(id: UUID)`. Manages upload queue with `TaskGroup` (max 3 concurrent). Calls `FileService` upload methods.
- **Modify:** `Views/FileList/FileListView.swift` — add `.onDrop(of:)` modifier, upload button in toolbar, progress overlay
- **Drive ID resolution:** The upload target's `driveId` and `parentItemId` must be resolved from the current breadcrumb state. For OneDrive, these are available directly. For SharePoint sites and Teams channels, resolve from the current folder's `UnifiedFile.driveId` property (already stored from initial navigation). If `driveId` is nil or empty (which should not happen for navigated folders), show an error alert.

### Edge Cases
- Upload to the same folder the user is viewing: refresh file list on each completed upload
- Network interruption during resumable upload: retry from last successful chunk (session URL persists for 48h)
- Zero-byte files: use simple upload path regardless of size threshold
- Frecency: record access only after successful upload completion
- Cross-drive context: upload always targets the current folder's drive — no cross-drive concern since the file data comes from Finder (local), not another Graph drive

---

## Feature 2: Rename Files & Folders

### Goal
Inline rename from the file list via context menu, keyboard shortcut, or slow double-click.

### API Design
```
PATCH /drives/{driveId}/items/{itemId}
Body: {"name": "new-name.ext"}
```

### UI Specification

- **Triggers:**
  - Context menu: "Rename" item
  - Keyboard: F2 key on single selection (avoids conflict with existing Enter key behavior which navigates into folders / opens files via `handleDoubleClick`). Note: the current `.onKeyPress(.return)` in `FileListView` maps to open/navigate and must be preserved. F2 is the standard rename shortcut on Windows and is familiar to Microsoft 365 users.
  - Mouse: Context menu only for initial implementation. Slow double-click (Finder-style) is complex to implement in SwiftUI (requires distinguishing single click, double click, and slow double-click with custom gesture handling) — defer to a later polish pass.
- **Inline editing:** `FileRowView` replaces the name `Text` with an editable `TextField`. Pre-selects the name without the file extension (matching Finder behavior).
- **Commit:** Press Enter or click away to confirm. Press Escape to cancel.
- **Validation:** Reuse `FolderNameValidator` logic — reject `/ \ : * ? " < > |` characters. Show inline red text below the field if invalid.
- **Optimistic UI:** Immediately update the displayed name. Revert with error alert on API failure.

### Architecture

- **Modify:** `Networking/GraphClient.swift` — add `renameItem(driveId:itemId:newName:)` endpoint
- **Modify:** `ViewModels/FileListViewModel.swift` — add `renameItem(_ item: UnifiedFile, to newName: String)`
- **Modify:** `Views/FileList/FileRowView.swift` — add `@State var isRenaming: Bool`, conditional `TextField` rendering
- **Modify:** `Views/FileList/FileListView.swift` — wire context menu item and keyboard shortcut

### Edge Cases
- Renaming a folder: same API, same UI
- Rename conflict (name already exists): API returns 409 Conflict — show alert "A file with this name already exists"
- Empty name: prevent submission (disable confirm)
- Extension change: show confirmation dialog "Are you sure you want to change the file extension?"

---

## Feature 3: Grid/Icon View Toggle

### Goal
Alternative thumbnail-based grid layout for the file list, toggled via toolbar control.

### UI Specification

- **Toggle control:** Segmented control or icon button pair in the toolbar area (SF Symbols: `list.bullet` / `square.grid.2x2`). Placed near the sort controls.
- **Grid layout:** `LazyVGrid` with `GridItem(.adaptive(minimum: 150))`. Each cell:
  - Large thumbnail (120x120pt) with rounded corners, loaded async via Graph API thumbnail endpoint
  - File type icon as fallback when no thumbnail available
  - Filename below (2-line truncation)
  - Subtle source badge in corner
  - Folder items show folder icon with slight shadow
- **Interactions:** Click = select (highlighted border), double-click = open/navigate. Multi-select with Cmd+Click and Shift+Click. Same context menu as list view.
- **Drag-and-drop:** Reorder and move work in grid view. Upload drop zone overlays the grid.
- **Sort:** Same sort order as list view. Sort controls remain in toolbar.
- **State:** Global view mode preference stored in `UserDefaults` key `fileViewMode`.

### Architecture

- **New file:** `Views/FileList/FileGridView.swift` — grid layout using `LazyVGrid`
- **New file:** `Views/FileList/FileGridCellView.swift` — individual grid cell view
- **Modify:** `Views/FileList/FileListView.swift` — add toggle, wrap content in `if viewMode == .list { ... } else { ... }`
- **Modify:** `ViewModels/FileListViewModel.swift` — add `@Published var viewMode: ViewMode` (enum: `.list`, `.grid`)
- Shared selection state and context menu logic remain in `FileListViewModel`

### Edge Cases
- Very long filenames: 2-line truncation with ellipsis in grid cells
- Thumbnail loading failure: show file type SF Symbol icon at same size
- Empty folder in grid view: same empty state view as list
- Rapid view toggling: no animation glitches (use `withAnimation`)

---

## Feature 4: Tabs (Multi-Folder)

### Goal
Open multiple locations simultaneously in tabs within the detail pane, each with independent navigation state.

### Architecture

**New `TabManager` class (`ViewModels/TabManager.swift`):**
```swift
@MainActor @Observable
class TabManager {
    var tabs: [Tab]
    var activeTabId: UUID

    func addTab(at location: TabLocation? = nil) -> Tab
    func closeTab(id: UUID)
    func switchToTab(id: UUID)
    func moveTab(from: Int, to: Int)
    var activeTab: Tab { ... }
}

/// Tab uses a class (not struct) because it holds a reference-type ViewModel
/// and needs stable identity for SwiftUI's ForEach and drag reorder.
class Tab: Identifiable, Equatable {
    let id: UUID
    let viewModel: FileListViewModel
    var title: String
    var icon: String
    var location: TabLocation
    var loadTask: Task<Void, Never>?  // per-tab load task for cancellation

    static func == (lhs: Tab, rhs: Tab) -> Bool { lhs.id == rhs.id }
}

/// Represents a navigable location for tab persistence.
enum TabLocation: Codable, Equatable {
    case myDrive                                    // OneDrive root
    case recent                                     // Recent files
    case sharedWithMe                               // Shared with Me
    case folder(driveId: String, folderId: String)  // Specific folder in any drive
    case siteDrives(siteId: String, siteName: String)  // SharePoint site root
    case teamChannels(siteId: String, siteName: String) // Teams site channels
}
```

- Each `Tab` owns an independent `FileListViewModel` instance
- **Task cancellation per tab:** Each `Tab` holds an optional `loadTask: Task<Void, Never>?`. When switching tabs, the previous tab's load task is NOT cancelled (it continues in the background). When closing a tab, its load task IS cancelled. When navigating within a tab (folder change), the tab's load task is cancelled and replaced — matching the existing pattern in `MainView`.
- Currently `MainView` stores `loadContentTask` and cancels on sidebar changes. After tabs, this moves INTO each `Tab` object, and `TabManager` manages the lifecycle.
- Switching tabs is instant (no reload — the ViewModel retains its state)
- `TabManager` is injected at `MainView` level, replacing the current single `FileListViewModel` reference
- Sidebar navigation acts on `TabManager.activeTab.viewModel`
- **Memory management:** Each tab's `FileListViewModel` has its own 50-entry in-memory cache. With 10 tabs, worst case is 500 cached entries. To mitigate: when tab count exceeds 5, reduce per-ViewModel cache to 25 entries. Background tabs that haven't been viewed in >10 minutes can have their cache evicted (they'll reload on next switch).

### UI Specification

- **Tab bar:** Horizontal bar above the file list area. Each tab: icon + title + close button (shown on hover). "+" button at right end.
- **Tab creation:**
  - Cmd+T: new tab duplicating current location
  - Cmd+click on folder or sidebar item: open in new tab
  - Context menu: "Open in New Tab"
- **Tab close:**
  - Cmd+W: close current tab (no-op if last tab)
  - Click close button (x)
  - Always keep at least 1 tab open
- **Tab switching:** Click tab, Cmd+Shift+[ / ] to cycle, Cmd+1 through Cmd+9 to jump
- **Drag reorder:** Tabs can be dragged left/right to reorder
- **Tab limit:** 10 tabs max. "+" button disabled at limit with tooltip.
- **Persistence:** Save `[TabLocation]` array to `UserDefaults` on quit. Restore on launch.

### Files to Create/Modify

- **New:** `ViewModels/TabManager.swift`
- **New:** `Views/Tabs/TabBarView.swift`
- **New:** `Views/Tabs/TabItemView.swift`
- **Modify:** `Views/MainView.swift` — integrate TabManager, route sidebar navigation through it
- **Modify:** `App/` entry point — create and inject TabManager

### Migration Strategy
- Current code references a single `FileListViewModel` from `MainView`
- After tabs: `MainView` holds `TabManager`, and any code that needs the ViewModel accesses `tabManager.activeTab.viewModel`
- All other features (upload, rename, grid view, etc.) work against `FileListViewModel` — they don't need to know about tabs

### Edge Cases
- Search opens result in active tab (or new tab via context menu)
- Closing a tab while it's loading: cancel the tab's ViewModel's load task
- All tabs closed scenario: prevented by UI (last tab can't be closed)
- Memory: each tab's ViewModel holds its file cache; 10 tabs with large folders could use significant memory. Mitigate with stale-while-revalidate cache eviction.

---

## Feature 5: File Version History

### Goal
View and restore previous file versions from the inspector pane.

### API Design

**List versions:**
```
GET /drives/{driveId}/items/{itemId}/versions
```

**Download a version:**
```
GET /drives/{driveId}/items/{itemId}/versions/{versionId}/content
```

**Restore a version:**
```
POST /drives/{driveId}/items/{itemId}/versions/{versionId}/restoreVersion
```

### Data Model

```swift
struct FileVersion: Identifiable {
    let id: String
    let label: String           // e.g., "2.0", "1.0"
    let lastModifiedBy: String  // display name
    let lastModifiedDateTime: Date
    let size: Int64
}
```

### UI Specification

- **Location:** Collapsible "Version History" section in `FileDetailView`, below the existing metadata section
- **Section header:** "Version History" with disclosure triangle and version count badge
- **Version rows:** Each shows: version label, relative timestamp ("2 days ago"), modified-by name, size
- **Actions per row:**
  - "Download" button (SF Symbol: `arrow.down.circle`) — downloads that version to ~/Downloads
  - "Restore" button (SF Symbol: `arrow.uturn.backward.circle`) — confirmation dialog first, then restores
- **Loading:** Versions fetched on-demand when section is first expanded. Brief in-memory cache (5 min).
- **Scope:** Section hidden for folders. Restore button disabled for read-only items.

### Architecture

- **New:** `Models/FileVersion.swift`
- **New:** `ViewModels/VersionHistoryViewModel.swift`
- **Modify:** `Networking/GraphClient.swift` — add `getVersions()`, `downloadVersion()`, `restoreVersion()` endpoints
- **Modify:** `Views/FileList/FileDetailView.swift` — add version history section

### Platform-Specific Behavior
- **OneDrive Personal:** Limited version support — may only store major versions. The versions endpoint may return fewer results or an empty array. Handle gracefully: show "No version history available" if the array is empty.
- **OneDrive for Business:** Full version history support with configurable retention.
- **SharePoint:** Can have both major and minor versions depending on library settings. Minor versions (e.g., "0.1", "0.2") may appear — display them all.
- **404 response:** If the versions endpoint returns 404 (unsupported for item type or plan), hide the section entirely rather than showing an error.

---

## Feature 6: Enhanced Inspector Preview

### Goal
Richer, more interactive file previews replacing the current static thumbnail in the inspector.

### Preview Strategies by MIME Type

| Type | Rendering | Source |
|------|-----------|--------|
| Images (JPEG, PNG, GIF, WebP) | Full-res with pinch-to-zoom, fit/fill toggle | Graph API content endpoint via GraphClient |
| PDFs | Multi-page with prev/next navigation | PDFKit from temp download |
| Office (docx, xlsx, pptx) | Graph API preview thumbnails, multi-page carousel | Graph API thumbnail endpoint (large size) |
| Text/code (.txt, .md, .swift, .json) | Monospaced text, first ~100 lines, basic syntax highlighting | Graph API content endpoint |
| Other | File type icon + metadata (current behavior) | N/A |

### Architecture

**Each preview sub-view owns a lightweight ViewModel** (`@State private var` or a dedicated `@Observable` class) that handles the authenticated download via `GraphClient`. The `GraphClient` reference is passed down from the parent `FileDetailView` (which already has access via the environment or its own ViewModel). This avoids `AsyncImage` which cannot authenticate with Graph API.

**Dispatcher pattern:**
```swift
struct FilePreviewView: View {
    let file: UnifiedFile
    let graphClient: GraphClient  // passed from FileDetailView

    var body: some View {
        switch file.previewCategory {
        case .image:    ImagePreviewView(file: file, graphClient: graphClient)
        case .pdf:      PDFPreviewView(file: file, graphClient: graphClient)
        case .office:   OfficePreviewView(file: file, graphClient: graphClient)
        case .text:     TextPreviewView(file: file, graphClient: graphClient)
        case .other:    DefaultPreviewView(file: file)
        }
    }
}
```

Each sub-view uses a `@State` task to download content on appear, stores the result in `@State` (e.g., `NSImage` for images, `PDFDocument` for PDFs, `String` for text), and cancels the task on disappear/deselection.

### Files to Create/Modify

- **New:** `Views/Preview/FilePreviewView.swift` (dispatcher)
- **New:** `Views/Preview/ImagePreviewView.swift`
- **New:** `Views/Preview/PDFPreviewView.swift`
- **New:** `Views/Preview/OfficePreviewView.swift`
- **New:** `Views/Preview/TextPreviewView.swift`
- **Modify:** `Views/FileList/FileDetailView.swift` — replace thumbnail with `FilePreviewView`, pass `GraphClient`
- **Modify:** `Models/UnifiedFile.swift` or extension — add `previewCategory` computed property

### Edge Cases
- **Size limits:** Don't download >50MB files for preview (images, PDFs, or text). Show "File too large for preview" with a "Quick Look" button fallback. Check `file.size` before initiating download.
- Deselection: cancel any in-progress preview download task (via `.task(id: file.id)` modifier)
- Temp files: use same 24h cleanup as Quick Look files
- Network errors: show file type icon fallback with "Preview unavailable" message

---

## Feature 7: UI Polish Pass

### Goal
Collection of refinements that elevate the app's visual quality and native feel.

### Items

**Collapsible sidebar sections:**
- Favorites, Frequently Used, and Teams & Sites sections each wrapped in `DisclosureGroup`
- Expand/collapse state persisted per-section in `UserDefaults`
- Smooth spring animation on toggle
- **File:** `Views/MainView.swift`

**Loading skeletons:**
- New `SkeletonView` component with shimmer animation
- Replaces spinner-only states when loading file lists
- List skeleton: 5 rows of (icon placeholder + 2 text line placeholders)
- Grid skeleton: 6 cells of (thumbnail placeholder + text placeholder)
- **Files:** `Views/Common/SkeletonView.swift` (new), `Views/FileList/FileListView.swift`, `Views/FileList/FileGridView.swift`

**Smoother animations:**
- List-to-grid transition: use a simple crossfade (`.transition(.opacity)`) rather than `matchedGeometryEffect`, because `List` (backed by `NSTableView`) and `LazyVGrid` (inside `ScrollView`) live in different container hierarchies where matched geometry does not produce reliable hero animations on macOS. A clean crossfade is more predictable.
- Spring animation on sidebar section expand/collapse
- Row insertion/removal: `.transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))`
- **Files:** various view files

**Improved empty states:**
- Custom SF Symbol illustrations per state:
  - Empty folder: `folder.badge.questionmark`
  - No search results: `magnifyingglass`
  - No favorites: `star.slash`
  - Error: `exclamationmark.triangle`
- Actionable buttons: "Upload files" in empty folder, "Clear filters" in no search results
- **File:** `Views/Common/EmptyStateView.swift`

**Refined context menus:**
- Group actions with `Divider()`: Open group / Edit group / Danger group
- Keyboard shortcut hints shown as secondary text
- **File:** `Views/FileList/FileListView.swift`, `Views/FileList/FileRowView.swift`

**Source badges:**
- Color-coded: OneDrive (#0078D4), SharePoint (#038387), Teams (#6264A7)
- Smaller pill shape, positioned inline with metadata
- **File:** `Views/FileList/FileRowView.swift`

---

## Implementation Order

| Phase | Feature | Rationale |
|-------|---------|-----------|
| 1 | Rename | Smallest scope, no architectural changes, good warm-up |
| 2 | Upload | Second core gap, independent of other features |
| 3 | Grid View | Purely additive UI, no impact on existing file list logic |
| 4 | UI Polish | Incremental, best done before Tabs changes the layout |
| 5 | Enhanced Preview | Independent, enriches inspector pane |
| 6 | Version History | Builds on inspector (after Enhanced Preview) |
| 7 | Tabs | Most architecturally complex, restructures ViewModel ownership — do last |

---

## Verification Checklist

- [ ] **Upload:** Drag file from Finder into OneDrive folder -> file appears. Upload >4MB file -> progress shown, completes. Upload to SharePoint -> works. Upload to read-only location -> disabled.
- [ ] **Rename:** Right-click -> Rename -> inline edit -> confirm -> name updates. Invalid characters -> validation. API failure -> revert with alert.
- [ ] **Grid View:** Toggle to grid -> thumbnails load. Select, double-click, context menu all work. Toggle back -> state preserved.
- [ ] **Tabs:** Cmd+T -> new tab. Navigate in tab A, switch to B -> state preserved. Close tab -> works. Relaunch -> tabs restored.
- [ ] **Version History:** Select file -> expand Versions -> listed. Download version -> saves. Restore -> confirmation -> restored.
- [ ] **Enhanced Preview:** Image -> zoomable. PDF -> page navigation. Code file -> syntax-highlighted. Large file -> graceful fallback.
- [ ] **UI Polish:** Collapse sidebar section -> persists on relaunch. Loading -> skeleton. Empty folder -> illustration + upload button.
