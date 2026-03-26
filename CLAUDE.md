# CLAUDE.md — BetterMSFile

## Project Overview

BetterMSFile is a native macOS app (Swift/SwiftUI) that provides a unified file browser for Microsoft 365 (OneDrive, SharePoint, Teams). It communicates with the Microsoft Graph API for file operations and uses MSAL for authentication.

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
├── Extensions/    # Utility extensions
├── Config.swift   # Azure AD credentials (not committed)
└── scripts/       # Release automation
```

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

**Always use the release script** — never create DMGs or GitHub releases manually.

```bash
# From the repo root:
./scripts/release.sh <version> <path-to-app>

# Examples:
./scripts/release.sh 1.7 ./BetterMSFileV1.7.app
./scripts/release.sh --notes release-notes.md 1.7 ./BetterMSFileV1.7.app
./scripts/release.sh --dmg-only 1.7 ./BetterMSFileV1.7.app
```

The script handles everything:
- Generates a background image with drag-to-install instructions
- Creates a DMG with `BetterMSFile.app` + `Applications` symlink + Finder layout
- Tags the commit, pushes the tag, creates the GitHub release
- Verifies the DMG contents before uploading

**Release conventions:**
- Tag format: `v{VERSION}` (e.g., `v1.65`)
- DMG name: `BetterMSFile-v{VERSION}.dmg`
- App inside DMG is always named `BetterMSFile.app` (no version suffix) so users can drag-to-replace
- Release title: `BetterMSFile v{VERSION}`
- Ensure `MARKETING_VERSION` in Xcode matches the release version before building

**Flags:**
- `--dmg-only` — Build DMG without tagging or publishing (for testing)
- `--no-tag` — Skip git tag creation (when tag already exists)
- `--notes FILE` — Use a file for release notes instead of auto-generated notes

## Build & Run

1. Requires Xcode and macOS 26.2+
2. `Config.swift` must contain valid Azure AD credentials (client ID, tenant ID) — this file is not committed
3. Open `BetterMSFile.xcodeproj`, build and run

## Dependencies

- **MSAL** (Microsoft Authentication Library) — via Swift Package Manager
- **Pillow** (Python) — used by `scripts/release.sh` to generate DMG background images. Install with `pip3 install Pillow` if not present.

## Common Pitfalls

- **Don't create DMGs with `hdiutil` directly** — use `scripts/release.sh` to get the correct background, layout, and Applications shortcut.
- **Don't skip task cancellation** — every sidebar navigation must cancel the previous in-flight load. Without this, rapid folder switching causes stale data.
- **Don't use force-unwraps for URL construction** — Graph API URLs with special characters in paths will crash. Always use optional binding.
- **Don't bypass `GraphClient`** — it handles auth, retry, throttle. Raw URLSession calls will miss token refresh and 429 backoff.
- **Don't record frecency on intent** — only record after the action succeeds (open, preview, download).
