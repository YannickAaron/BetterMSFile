# Update Notification System — Design Spec

## Summary

Add an update notification system to BetterMSFile that checks GitHub Releases for newer versions and notifies the user via an alert dialog (once per launch) and a persistent sidebar badge. Notification only — no auto-download or auto-install.

## Context

- BetterMSFile is a native macOS SwiftUI app, currently at v1.2
- Distributed as a signed/notarized `.dmg` via GitHub Releases at `YannickAaron/BetterMSFile`
- Releases are created manually (build in Xcode, create GitHub Release, upload DMG)
- No update mechanism exists today

## Approach

Query the GitHub Releases API (`/repos/YannickAaron/BetterMSFile/releases/latest`) on app launch. Compare the release tag against the running app's version. If a newer version exists, show a notification and link to the download.

## Architecture

### New: `UpdateService`

Location: `BetterMSFile/BetterMSFile/Services/UpdateService.swift`

A plain class (matching the pattern of `FileService`, `SearchService`, etc.) with no dependencies on auth, Graph, or any other service. `AppState` is `@Observable` and owns this service, so SwiftUI views will react to state changes via `appState.updateService` property access.

**State:**
- `updateAvailable: Bool` — true when remote version > local version
- `latestVersion: String?` — the version string from the latest release
- `downloadURL: URL?` — the `html_url` of the GitHub Release page
- `lastCheckDate: Date?` — when the last successful check occurred

**Methods:**
- `checkForUpdate()` async — fetches the latest release, parses the response, updates state
- Silent on failure — logs errors to console, never throws or surfaces errors to the user

**Version comparison logic:**
1. Get `tag_name` from the GitHub API response
2. Strip leading `v` if present (e.g., `v1.3` -> `1.3`)
3. Get local version from `Bundle.main.infoDictionary["CFBundleShortVersionString"]`
4. Split both on `.`, compare each component as integers left to right. Missing components are treated as `0` (e.g., `1.2` is equivalent to `1.2.0`)
5. Remote is newer if any component is greater (with earlier components being equal)

### GitHub API

**Endpoint:** `GET https://api.github.com/repos/YannickAaron/BetterMSFile/releases/latest`

**Auth:** None (unauthenticated). Rate limit is 60 requests/hour per IP — one check per launch is well within limits.

**Response fields used:**
- `tag_name` — version string (e.g., `"v1.3"` or `"1.3"`)
- `html_url` — link to the release page for the user to download

**Response model:**
```swift
struct GitHubRelease: Codable {
    let tagName: String
    let htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
    }
}
```

### Integration with AppState

- `AppState` owns an `UpdateService` instance (published property so views can access `appState.updateService.updateAvailable`)
- `restoreSession()` triggers the first update check **unconditionally at the end** — not inside the `if authService.isAuthenticated` block. Update checking is auth-independent.
- The `didBecomeActive` handler in `BetterMSFileApp.swift` calls `appState.updateService.checkForUpdate()` **directly** (not via `backgroundRefresh()`, which guards on auth). Debounced:
  - Skip if `lastCheckDate` is less than 1 hour ago
  - This handles the case where the user leaves the app open and reactivates it days later

### UI

#### Alert Dialog (once per session)

Shown via `.alert()` on `ContentView` (not `MainView`) so it appears regardless of auth state. Triggers when `UpdateService` first detects an update in the current session.

- **Title:** "Update Available"
- **Message:** "BetterMSFile {latestVersion} is available. You're running {currentVersion}."
- **Primary button:** "Download" — opens `downloadURL` in the default browser via `NSWorkspace.shared.open()`
- **Secondary button:** "Later" — dismisses the alert

The alert shows at most once per app launch. A boolean flag (`hasShownUpdateAlert`) in `AppState` or a view tracks this.

#### Sidebar Badge

After the alert is dismissed (or if the user chose "Later"), a persistent visual indicator appears in the sidebar:

- Location: bottom of the sidebar section in `MainView.swift` (the `sidebar` `@ViewBuilder` property — note: `SidebarView.swift` is a stub, the actual sidebar lives in `MainView`)
- Appearance: small dot or "Update available" text link
- Action: clicking opens `downloadURL` in the browser
- Visibility: remains visible as long as `updateAvailable` is true (i.e., until the user updates and relaunches)

### Error Handling

- **Network failure:** Silently ignored. No retry. The next launch/activation will try again.
- **Non-200 response:** Log to console, set no update state.
- **Unparseable JSON:** Log to console, set no update state.
- **No releases exist:** Treat as no update available.
- Update checking must never block app startup or degrade the user experience.

## Files to Create/Modify

### New files:
- `BetterMSFile/BetterMSFile/Services/UpdateService.swift` — the update checking service and `GitHubRelease` response model

### Modified files:
- `BetterMSFile/BetterMSFile/App/AppState.swift` — add `UpdateService` property, trigger check unconditionally at end of `restoreSession()`
- `BetterMSFile/BetterMSFile/Views/MainView.swift` — add update badge to the `sidebar` `@ViewBuilder` (not `SidebarView.swift`, which is a stub)
- `BetterMSFile/BetterMSFile/ContentView.swift` — add `.alert()` modifier for the update dialog (on `ContentView` so it works regardless of auth state)
- `BetterMSFile/BetterMSFile/BetterMSFileApp.swift` — add direct `updateService.checkForUpdate()` call in `didBecomeActive` handler (separate from `backgroundRefresh()`)

## Out of Scope

- Auto-download or auto-install (Sparkle-style)
- "Don't remind me" or version-specific dismissal
- Release notes display in the alert
- CI/CD pipeline for automated releases
- Checking for pre-release versions

## Future Considerations

- Could add release notes display by parsing the `body` field from the GitHub API response
- Could add "Skip this version" functionality if users find notifications annoying
- Could migrate to Sparkle if auto-update becomes desired
