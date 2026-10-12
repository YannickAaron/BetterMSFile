# BetterMSFile

**[Visit the website](https://yannickaaron.github.io/BetterMSFile/)** — Learn more and download the app.

A lightweight native app for fast, unified access to Microsoft 365 files across OneDrive, SharePoint and Teams — for **macOS** (SwiftUI) and **Linux** (GNOME / GTK 4, beta).

## Why

Microsoft's default apps (OneDrive, SharePoint, Teams) scatter files across fragmented interfaces. Finding a file means knowing which app to open and which site to check. BetterMSFile merges everything into a single, fast, keyboard-first file browser.

## Features

- **Unified file view** — OneDrive, SharePoint, and shared files in one place
- **Fast search** — Global search across all sources via Microsoft Graph Search API
- **Scoped search** — Filter search to a specific team, site, or your OneDrive
- **Favorites** — Pin frequently used files and folders for instant access (Cmd+D)
- **Frequently Used** — Smart suggestions based on your usage patterns (frecency)
- **Drag-and-drop reorder** — Custom file ordering per folder, persisted across sessions
- **Keyboard-first** — Navigate entirely with keyboard shortcuts (Cmd+K search, arrow keys, Space for Quick Look)
- **Native on each platform** — SwiftUI on macOS, GTK 4 / libadwaita on Linux
- **Instant startup** — Local cache with background refresh
- **Quick Look** — Preview files without downloading
- **Open anywhere** — Open in browser, download, copy link, drag & drop
- **AI agents (MCP)** — Let Claude, Cursor and other MCP clients search and read your files

### macOS vs. Linux

| | macOS | Linux (beta) |
|---|---|---|
| Browse OneDrive, Recent, Shared, SharePoint & Teams | ✓ | ✓ |
| Search | ✓ (with scopes & filters) | ✓ |
| Open, download, open in browser, copy link | ✓ | ✓ |
| New folder, rename, delete | ✓ | ✓ |
| Move, upload, drag & drop | ✓ | — |
| Quick Look, version history, tabs, grid view | ✓ | — |
| Favorites, frequently used, offline cache | ✓ | — |
| AI agents (MCP server) | ✓ | ✓ |

## Requirements

- Microsoft 365 work/school account
- Azure AD app registration with delegated permissions (see [Graph API Scopes](#graph-api-scopes)); the same registration and redirect URI work for both platforms
- **macOS:** macOS 26.2+ (Xcode to build from source)
- **Linux:** GTK ≥ 4.20 and libadwaita ≥ 1.8 (Ubuntu 26.04, Fedora 43 or newer), `libsecret-tools` (stores the sign-in in your keyring), `poppler-utils` (PDF/Office text for AI agents); Swift 6.3+ only to build from source

## Install

### macOS

Download the latest DMG from the [website](https://yannickaaron.github.io/BetterMSFile/) or [GitHub Releases](https://github.com/YannickAaron/BetterMSFile/releases), open it and drag **BetterMSFile** to Applications.

To build from source:

1. Clone the repository
2. Copy `BetterMSFile/Config.swift.example` to `BetterMSFile/Config.swift`
3. Fill in your Azure AD app registration values (client ID, tenant ID)
4. Open `BetterMSFile.xcodeproj` in Xcode
5. Build and run

### Linux (beta)

**Prebuilt (recommended).** Download `BetterMSFile-vX-linux-x86_64.tar.gz` (or `-aarch64`) from [GitHub Releases](https://github.com/YannickAaron/BetterMSFile/releases) (Linux builds may be marked pre-release while in beta). It includes the Swift runtime, so you don't need Swift.

```bash
sudo apt install libadwaita-1-0 libsecret-tools poppler-utils    # Ubuntu 26.04 / Debian
sudo dnf install libadwaita libsecret poppler-utils              # Fedora 43+
tar xzf BetterMSFile-v*-linux-*.tar.gz
cd BetterMSFile-v*-linux-*/ && ./install.sh
```

Start **BetterMSFile** from your app launcher (or run `bettermsfile`) and click **Sign in with Microsoft**. To update, install the new tarball the same way; to remove, run `./install.sh --uninstall`.

**From source.** The same script builds a release binary first when run from a checkout:

1. Install the dependencies:

   ```bash
   # Ubuntu 26.04 / Debian
   sudo apt install libadwaita-1-dev libgtk-4-dev libsqlite3-dev pkg-config libsecret-tools poppler-utils
   # Fedora 43+
   sudo dnf install libadwaita-devel gtk4-devel sqlite-devel pkgconf libsecret poppler-utils
   ```

2. Install Swift 6.3 or newer from [swift.org/install/linux](https://www.swift.org/install/linux/).
3. Clone the repository, copy `BetterMSFile/Config.swift.example` to `BetterMSFile/Config.swift` and fill in your Azure app values.
4. Build and install:

   ```bash
   ./scripts/install-linux.sh
   ```

5. Start **BetterMSFile** from your app launcher (or run `bettermsfile`) and click **Sign in with Microsoft**.

Both install for your user (no root): the app in `~/.local/lib/bettermsfile`, the `bettermsfile` command in `~/.local/bin`, a launcher in `~/.local/share/applications` and the icon. Run the script again to update, or with `--uninstall` to remove it.

Sign-in uses the same app registration and redirect URI as the Mac app (`msauth.empa.BetterMSFile://auth`). On first sign-in the app registers itself as the handler for that URL scheme, so your browser hands the result straight back — if the browser asks whether to open BetterMSFile, allow it. The refresh token is kept in your desktop keyring (GNOME Keyring / KWallet).

For development: `swift build && .build/debug/bettermsfile`.

## Releases

Bump `MARKETING_VERSION` in Xcode, commit, then push a tag:

```bash
git tag v1.9 && git push origin v1.9
```

The [Release workflow](.github/workflows/release.yml) builds the signed and notarized macOS DMG and the Linux tarballs (x86_64 and aarch64), and publishes them with checksums as the GitHub release `v1.9`. It needs these repository secrets: `CONFIG_SWIFT`, `MACOS_CERTIFICATE_P12`, `MACOS_CERTIFICATE_PASSWORD`, `ASC_API_KEY_P8`, `ASC_API_KEY_ID`, `ASC_API_ISSUER_ID` (see the workflow header). `./scripts/release.sh` still works for a local macOS-only release.

## Architecture

```
Views (SwiftUI on macOS · adwaita-swift on Linux)
        → ViewModels → Services → GraphClient → Microsoft Graph API
                          ↕
          SwiftData cache (macOS) · MSAL / OAuth+PKCE (auth)
```

**MVVM with service layer:**
- **Views** — SwiftUI `NavigationSplitView` on macOS; GTK 4 / libadwaita via [adwaita-swift](https://git.aparoksha.dev/aparoksha/adwaita-swift) on Linux
- **ViewModels** — State management, business logic (`AppState`, sidebar and search view models are shared by both platforms)
- **Services** — File fetching, search, site discovery (shared)
- **GraphClient** — Authenticated HTTP with pagination and throttle handling (shared)
- **SwiftData** — Local metadata cache for instant startup (macOS)
- **Auth** — MSAL with Keychain on macOS; OAuth 2.0 auth code + PKCE with the desktop keyring on Linux

The Linux build is the SwiftPM package in `Package.swift`: it compiles the shared files in place from `BetterMSFile/` and adds Linux-only code from `Linux/Sources`. The Mac app is still built with the Xcode project.

## Project Structure

```
BetterMSFile/
├── App/              # App entry point, global state (AppState is shared with Linux)
├── Auth/             # MSAL authentication service (macOS)
├── MCP/              # MCP server for AI agents (shared)
├── Networking/       # Graph API client, endpoints, response types (shared)
├── Services/         # File, search, and site services (shared)
├── Models/           # SwiftData models (UnifiedFile, FileSource)
├── ViewModels/       # View state management
├── Views/            # SwiftUI views (sidebar, file list, search, auth)
└── Extensions/       # Utility extensions
Linux/Sources/        # Linux app: GNOME UI, OAuth sign-in, folder browser, CLI entry point
Package.swift         # SwiftPM manifest for the Linux build
Vendor/               # adwaita-swift + its packages (vendored, MIT)
scripts/              # release.sh (macOS DMG), package-linux.sh + install-linux.sh (Linux)
.github/workflows/    # Linux CI build, tag-triggered release (DMG + Linux tarballs)
```

## Use with AI agents (MCP)

BetterMSFile can give AI agents (Claude Desktop, Claude Code, Cursor and other MCP clients) access to your Microsoft 365 files.

**macOS**

1. Sign in to BetterMSFile and move it to `/Applications`.
2. Open **Settings → Agents** (⌘,) and turn on **Let AI agents access my files**.
3. Click **Add to Claude** (Claude Desktop), **Copy Command** (Claude Code) or **Copy JSON** (other apps).

**Linux**

1. Sign in to BetterMSFile (or run `bettermsfile --login`).
2. Open the menu (☰) → **AI Agents…** and turn on **Allow agents to read files** (or run `bettermsfile --agent-access read`).
3. Add it to your client, e.g. `claude mcp add bettermsfile -- bettermsfile --mcp`.

Agents can list, search, read (text, PDF, Word, Excel, PowerPoint) and download files. Uploading, renaming, moving, creating folders and deleting stay off until you turn on **Allow agents to make changes** (Linux: **Allow agents to change files** or `--agent-access write`). Deleted items go to the Microsoft 365 recycle bin.

Under the hood, the app binary runs as a stdio MCP server with `--mcp`, reusing your signed-in session. It never opens a sign-in window. If your session expires, open the app and sign in again.

The Linux binary is also a small CLI: `bettermsfile --login`, `--logout`, `--agent-access off|read|write`, `--mcp`.

## Keyboard Shortcuts (macOS)

| Shortcut | Action |
|----------|--------|
| Cmd+K | Global search |
| ↑ / ↓ | Navigate file list |
| Enter | Open file / enter folder |
| Cmd+O | Open in browser |
| Cmd+D | Toggle favorite |
| Space | Quick Look preview |
| Escape | Dismiss search / go back |
| Cmd+[ / Cmd+] | Back / forward |

## Dependencies

- [MSAL for macOS](https://github.com/AzureAD/microsoft-authentication-library-for-objc) — Microsoft authentication (macOS, via SPM)
- [adwaita-swift](https://git.aparoksha.dev/aparoksha/adwaita-swift) — GTK 4 / libadwaita UI with a SwiftUI-like API (Linux; vendored in `Vendor/` with its packages, see `Vendor/README.md`)
- [swift-crypto](https://github.com/apple/swift-crypto) — SHA-256 for the PKCE sign-in (Linux)

## Graph API Scopes

| Scope | Purpose |
|-------|---------|
| `User.Read` | User profile |
| `Files.ReadWrite.All` | OneDrive + SharePoint file access + move |
| `Sites.Read.All` | SharePoint site discovery |
