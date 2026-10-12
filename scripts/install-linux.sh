#!/usr/bin/env bash
# Build and install BetterMSFile for the current Linux user (no root needed).
#
#   ./scripts/install-linux.sh              build (release) and install to ~/.local
#   ./scripts/install-linux.sh --uninstall  remove binary, launcher and icon
#
# Installs:
#   ~/.local/bin/bettermsfile                                        the app, CLI and MCP server
#   ~/.local/share/applications/com.empa.BetterMSFile.desktop        app launcher
#   ~/.local/share/icons/hicolor/scalable/apps/com.empa.BetterMSFile.svg
# The sign-in URL handler (bettermsfile-auth.desktop) is registered by the app on first sign-in.
set -euo pipefail

APP_ID="com.empa.BetterMSFile"
PREFIX="${PREFIX:-$HOME/.local}"
BIN="$PREFIX/bin/bettermsfile"
DESKTOP="$PREFIX/share/applications/$APP_ID.desktop"
ICON="$PREFIX/share/icons/hicolor/scalable/apps/$APP_ID.svg"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

refresh_caches() {
    update-desktop-database "$PREFIX/share/applications" 2>/dev/null || true
    gtk4-update-icon-cache -q -t "$PREFIX/share/icons/hicolor" 2>/dev/null \
        || gtk-update-icon-cache -q -t "$PREFIX/share/icons/hicolor" 2>/dev/null || true
}

if [[ "${1:-}" == "--uninstall" ]]; then
    rm -f "$BIN" "$DESKTOP" "$ICON" "$PREFIX/share/applications/bettermsfile-auth.desktop"
    refresh_caches
    echo "Uninstalled. Your sign-in stays in the keyring until you run 'bettermsfile --logout' (before uninstalling)."
    exit 0
fi

# --- Checks -------------------------------------------------------------------

fail() { echo "error: $*" >&2; exit 1; }

[[ "$(uname -s)" == "Linux" ]] || fail "this script is for Linux. On macOS, open BetterMSFile.xcodeproj or use scripts/release.sh."
command -v swift >/dev/null || fail "Swift 6.3+ not found. Install it from https://www.swift.org/install/linux/"
[[ -f "$ROOT/BetterMSFile/Config.swift" ]] \
    || fail "BetterMSFile/Config.swift is missing. Copy BetterMSFile/Config.swift.example and fill in your Azure app values."

if ! pkg-config --atleast-version=1.8 libadwaita-1 2>/dev/null || ! pkg-config --atleast-version=4.20 gtk4 2>/dev/null; then
    fail "needs libadwaita >= 1.8 and GTK >= 4.20 development files (Ubuntu 26.04 / Fedora 43 or newer).
  Ubuntu/Debian: sudo apt install libadwaita-1-dev libgtk-4-dev libsqlite3-dev pkg-config libsecret-tools poppler-utils
  Fedora:        sudo dnf install libadwaita-devel gtk4-devel sqlite-devel pkgconf libsecret poppler-utils"
fi
command -v secret-tool >/dev/null || echo "warning: 'secret-tool' not found; install libsecret-tools (Ubuntu) or libsecret (Fedora) so sign-in can be saved."
command -v pdftotext >/dev/null || echo "warning: 'pdftotext' not found; install poppler-utils so AI agents can read PDFs and Office files."

# --- Build & install ------------------------------------------------------------

echo "Building (release)…"
swift build -c release --package-path "$ROOT"

install -Dm755 "$ROOT/.build/release/bettermsfile" "$BIN"
install -Dm644 "$ROOT/design/icon.svg" "$ICON"
mkdir -p "$(dirname "$DESKTOP")"
cat > "$DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=BetterMSFile
Comment=Browse OneDrive, SharePoint and Teams files
Exec="$BIN"
Icon=$APP_ID
Terminal=false
Categories=Office;FileTools;Network;
Keywords=OneDrive;SharePoint;Teams;Microsoft;365;Files;
StartupWMClass=$APP_ID
EOF
refresh_caches

echo
echo "Installed BetterMSFile to $BIN"
case ":$PATH:" in *":$PREFIX/bin:"*) ;; *) echo "Note: add $PREFIX/bin to your PATH to use 'bettermsfile' in a terminal." ;; esac
echo "Start it from your app launcher, or run: bettermsfile"
echo "AI agents (optional): claude mcp add bettermsfile -- $BIN --mcp"
