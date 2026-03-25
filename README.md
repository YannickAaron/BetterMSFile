# BetterMSFile

A lightweight native macOS app for fast, unified access to Microsoft 365 files across OneDrive and SharePoint.

## Download

[**Download BetterMSFile v1.2**](https://github.com/YannickAaron/BetterMSFile/releases/latest) — Signed and notarized `.dmg` for macOS. Open the DMG and drag BetterMSFile to Applications.

## Why

Microsoft's default apps (OneDrive, SharePoint, Teams) scatter files across fragmented interfaces. Finding a file means knowing which app to open and which site to check. BetterMSFile merges everything into a single, fast, keyboard-first file browser.

## Features

- **Unified file view** — OneDrive, SharePoint, and shared files in one place
- **Fast search** — Global search across all sources via Microsoft Graph Search API
- **Keyboard-first** — Navigate entirely with keyboard shortcuts (Cmd+K search, arrow keys, Space for Quick Look)
- **Native macOS** — Built with SwiftUI, feels like a system app
- **Instant startup** — Local cache with background refresh
- **Quick Look** — Preview files without downloading
- **Open anywhere** — Open in browser, download, copy link, drag & drop

## Requirements

- macOS 26.2+
- Microsoft 365 work/school account
- Azure AD app registration with delegated permissions:
  - `User.Read`
  - `Files.Read.All`
  - `Sites.Read.All`

## Setup

1. Clone the repository
2. Copy `BetterMSFile/Config.swift.example` to `BetterMSFile/Config.swift`
3. Fill in your Azure AD app registration values (client ID, tenant ID)
4. Open `BetterMSFile.xcodeproj` in Xcode
5. Build and run

## Architecture

```
SwiftUI Views → ViewModels → Services → GraphClient → Microsoft Graph API
                                ↕
                           SwiftData (cache)
                                ↕
                         MSAL (auth/tokens)
```

**MVVM with service layer:**
- **Views** — SwiftUI, NavigationSplitView (sidebar + file list + detail)
- **ViewModels** — State management, business logic
- **Services** — File fetching, search, site discovery
- **GraphClient** — Authenticated HTTP with pagination and throttle handling
- **SwiftData** — Local metadata cache for instant startup
- **MSAL** — Microsoft authentication, token management via Keychain

## Project Structure

```
BetterMSFile/
├── App/              # App entry point, global state
├── Auth/             # MSAL authentication service
├── Networking/       # Graph API client, endpoints, response types
├── Services/         # File, search, and site services
├── Models/           # SwiftData models (UnifiedFile, FileSource)
├── ViewModels/       # View state management
├── Views/            # SwiftUI views (sidebar, file list, search, auth)
└── Extensions/       # Utility extensions
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+K | Global search |
| ↑ / ↓ | Navigate file list |
| Enter | Open file / enter folder |
| Cmd+O | Open in browser |
| Cmd+D | Download file |
| Space | Quick Look preview |
| Escape | Dismiss search / go back |
| Cmd+[ / Cmd+] | Back / forward |

## Dependencies

- [MSAL for macOS](https://github.com/AzureAD/microsoft-authentication-library-for-objc) — Microsoft authentication (via SPM)

## Graph API Scopes

| Scope | Purpose |
|-------|---------|
| `User.Read` | User profile |
| `Files.Read.All` | OneDrive + SharePoint file access |
| `Sites.Read.All` | SharePoint site discovery |
