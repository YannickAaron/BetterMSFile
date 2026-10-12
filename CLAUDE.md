# CLAUDE.md — BetterMSFile

## Project Overview

BetterMSFile is a native app that provides a unified file browser for Microsoft 365 (OneDrive, SharePoint, Teams), for macOS (Swift/SwiftUI, MSAL) and Linux (Swift + GTK 4/libadwaita via adwaita-swift, beta). It communicates with the Microsoft Graph API for file operations. The same binary also runs as an MCP server (`--mcp`) for AI agents.

## Architecture

```
SwiftUI Views → ViewModels → Services → GraphClient → Microsoft Graph API
                                ↕
                           SwiftData (local cache)
                                ↕
                         MSAL (auth/tokens via Keychain)
```

- **MVVM with service layer** — Views never call the API directly.
- **`@MainActor`** — All ViewModels and UI-facing services run on the main actor. Never dispatch UI state updates from background threads.
- **`GraphClient`** — Single point of entry for all Microsoft Graph HTTP calls. Handles auth headers, pagination, retry on 429/5xx, and token refresh. All new API calls must go through `GraphClient`, never raw `URLSession`.

## Source Layout

```
BetterMSFile/
├── App/           # Entry point, global state
├── Auth/          # MSAL auth service
├── Networking/    # GraphClient, endpoints, response types
├── Services/      # File, search, site, update services
├── Models/        # SwiftData models (UnifiedFile, FileSource)
├── ViewModels/    # View state management
├── Views/         # SwiftUI components
├── MCP/           # MCP server (shared with Linux)
├── Extensions/    # Utility extensions
└── Config.swift   # Azure AD credentials (not committed)
Linux/Sources/     # Linux app: adwaita-swift UI, OAuth+PKCE AuthService, FolderBrowser, CLI entry
Package.swift      # SwiftPM manifest for the Linux build (lists the shared files it compiles)
design/            # Icon source + design specs
docs/              # GitHub Pages website
scripts/           # release.sh (macOS), install-linux.sh (Linux), ExportOptions.plist, DMG background
```

## Linux Build

- `Package.swift` compiles shared files **in place** from `BetterMSFile/` (explicit `sources:` list) plus `Linux/Sources`. No code is moved; the Xcode project is untouched.
- Linux provides same-named stand-ins for Apple-only types: `AuthService` (OAuth auth code + PKCE, refresh token via `secret-tool`) and `UnifiedFile` (plain class, no SwiftData). Keep their API in sync with the macOS versions.
- Shared files must compile on Linux: `import Observation` next to `@Observable`, `#if canImport(FoundationNetworking)` where `URLSession`/`URLRequest` are used, no AppKit/SwiftUI/SwiftData/PDFKit (guard with `#if canImport`), no `RelativeDateTimeFormatter`.
- Sign-in reuses the Mac redirect URI (`MSALConfig.redirectUri`); the app registers itself as the scheme handler and receives the redirect via `--auth-callback`. Don't switch to a localhost redirect — that needs app-registration changes.
- UI gotchas (adwaita-swift): GTK's loop doesn't drain Swift's main queue, so `LinuxApp` pumps it; wrap reads of `@Observable` models in `observe { }`; give every `.dialog`/`.alertDialog` on a view a unique `id:`; `MenuButton` actions are shared per label, so look up the target instead of capturing it.
- Build/test in a container: `swift:6.4-resolute` + `libadwaita-1-dev libgtk-4-dev` (needs GTK ≥ 4.20). CI: `.github/workflows/linux.yml`.

## Key Conventions

### API & Networking
- All Graph API calls go through `GraphClient` — never use raw `URLSession` for Microsoft Graph.
- Authenticated downloads (file content, Quick Look) must include `Bearer` token via `GraphClient`.
- Search queries must be KQL-escaped before sending to the Graph Search API (special characters like `()`, `:`, `*` break KQL).
- Paginated responses: always follow `@odata.nextLink` until exhausted. Never assume a single page is complete.

### Concurrency & Thread Safety
- ViewModels are `@MainActor`. State mutations happen on main.
- Use structured concurrency (`async let`, `TaskGroup`) for parallel loads (e.g., loading Teams + Sites simultaneously).
- When switching folders/sidebar items, **cancel the previous load task** before starting a new one. This prevents race conditions where stale data from an old request overwrites the current view.
- Token refresh failures must be caught and surfaced to the user (e.g., re-auth prompt), not silently swallowed.

### Error Handling
- All user-visible failures (downloads, moves, deletes, Quick Look) must show an alert dialog. Never fail silently.
- Sidebar sections that fail to load should show an error state with a Retry button.
- Cross-drive operations (OneDrive ↔ SharePoint) are not supported by the Graph API — detect and show a clear error before attempting the request.

### File Operations
- Folder names must be validated before sending to the API (reject invalid characters).
- File downloads: handle filename collisions by appending a counter (e.g., `report (1).pdf`).
- Quick Look temp files should be cleaned up periodically (24h expiry).
- Frecency/favorites: only record access after a successful operation, not before.

## Releases

**Normal flow: push a tag.** Bump `MARKETING_VERSION`, commit, `git tag v{VERSION} && git push origin v{VERSION}`. `.github/workflows/release.yml` then builds the notarized DMG (via `scripts/release.sh --dmg-only` with an App Store Connect API key), the Linux tarballs (`scripts/package-linux.sh`, x86_64 + aarch64, Swift runtime bundled) and publishes the release with `SHA256SUMS.txt`. Re-run for an existing tag via workflow_dispatch (assets are replaced). Secrets are listed in the workflow header.

Linux tarball name: `BetterMSFile-v{VERSION}-linux-{x86_64|aarch64}.tar.gz` (binary, bundled Swift libs with `$ORIGIN` rpath, `install.sh`, icon).

**Local fallback:** the release script below — never create DMGs or GitHub releases manually.

```bash
./scripts/release.sh                      # build, DMG, tag, GitHub release
./scripts/release.sh --dmg-only           # build + DMG only (testing)
./scripts/release.sh --notes notes.md     # custom release notes
./scripts/release.sh --app path/to.app    # package existing .app, skip build
```

The script:
- Reads the version from `MARKETING_VERSION` — bump it in Xcode, commit, then run
- Signs via the Xcode account, or via `ASC_KEY_PATH`/`ASC_KEY_ID`/`ASC_ISSUER_ID` (API key; also used for notarization) — that's how CI runs it
- Archives (Release) and exports with Developer ID signing (`scripts/ExportOptions.plist`, team RCX5S5E3D8). Needs that team's account in Xcode → Settings → Accounts
- Creates a DMG in `build/` with `BetterMSFile.app` + `Applications` symlink + background (`scripts/dmg-background.png`)
- Refuses a dirty tree or an existing tag; tags, pushes, creates the GitHub release

**Release conventions:**
- Tag format: `v{VERSION}` (e.g., `v1.65`)
- DMG name: `BetterMSFile-v{VERSION}.dmg`
- App inside DMG is always named `BetterMSFile.app` (no version suffix) so users can drag-to-replace
- Release title: `BetterMSFile v{VERSION}`

**Flags:**
- `--dmg-only` — Build DMG without tagging or publishing (for testing)
- `--no-tag` — Skip git tag creation (when tag already exists)
- `--notes FILE` — Use a file for release notes instead of auto-generated notes

## Build & Run

**macOS**
1. Requires Xcode and macOS 26.2+
2. `Config.swift` must contain valid Azure AD credentials (client ID, tenant ID) — this file is not committed
3. Open `BetterMSFile.xcodeproj`, build and run

**Linux**
1. GTK ≥ 4.20, libadwaita ≥ 1.8, Swift 6.3+ (Ubuntu 26.04 / Fedora 43+)
2. Same `Config.swift`
3. `swift build && .build/debug/bettermsfile`, or `./scripts/install-linux.sh` to install for the user

## Dependencies

- **MSAL** (Microsoft Authentication Library) — via Swift Package Manager (macOS)
- **adwaita-swift** (pinned commit) and **swift-crypto** — via `Package.swift` (Linux)

## Common Pitfalls

- **Don't create DMGs with `hdiutil` directly** — use `scripts/release.sh` to get the correct background, layout, and Applications shortcut.
- **Don't skip task cancellation** — every sidebar navigation must cancel the previous in-flight load. Without this, rapid folder switching causes stale data.
- **Don't use force-unwraps for URL construction** — Graph API URLs with special characters in paths will crash. Always use optional binding.
- **Don't bypass `GraphClient`** — it handles auth, retry, throttle. Raw URLSession calls will miss token refresh and 429 backoff.
- **Don't record frecency on intent** — only record after the action succeeds (open, preview, download).
