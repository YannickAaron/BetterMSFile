#!/bin/bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────
# BetterMSFile Release Script
# Builds the app (Release), packages a DMG (background + Applications
# shortcut + icon layout) and publishes a GitHub release.
# Version is read from MARKETING_VERSION in the Xcode project.
#
# Usage:  ./scripts/release.sh [--dmg-only] [--no-tag] [--notes FILE] [--app PATH]
#
#   --dmg-only    Build the DMG but skip tagging & GitHub release
#   --no-tag      Skip git tag creation (use when tag already exists)
#   --notes FILE  Read release notes from FILE instead of --generate-notes
#   --app PATH    Package an already-built .app instead of building
#   --skip-notarize  Skip notarization (local testing only)
#
# Notarization needs a one-time keychain profile:
#   xcrun notarytool store-credentials BetterMSFile-notary \
#       --apple-id <apple-id> --team-id RCX5S5E3D8 --password <app-specific-password>
# ──────────────────────────────────────────────────────────────────────

APP_NAME="BetterMSFile"
REPO="YannickAaron/BetterMSFile"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="${ROOT}/${APP_NAME}.xcodeproj"
BUILD_DIR="${ROOT}/build"
cd "$ROOT"

DMG_ONLY=false
SKIP_TAG=false
NOTES_FILE=""
APP_PATH=""
NOTARIZE=true
NOTARY_PROFILE="BetterMSFile-notary"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dmg-only)  DMG_ONLY=true; shift ;;
        --no-tag)    SKIP_TAG=true; shift ;;
        --notes)     NOTES_FILE="$2"; shift 2 ;;
        --app)       APP_PATH="$2"; shift 2 ;;
        --skip-notarize) NOTARIZE=false; shift ;;
        *)           echo "Unknown argument: $1"; exit 1 ;;
    esac
done

VERSION=$(xcodebuild -project "$PROJECT" -scheme "$APP_NAME" -showBuildSettings 2>/dev/null \
    | awk '/ MARKETING_VERSION =/ && !v {v=$3} END {print v}')
[ -n "$VERSION" ] || { echo "Error: could not read MARKETING_VERSION."; exit 1; }
TAG="v${VERSION}"
DMG_NAME="${BUILD_DIR}/${APP_NAME}-${TAG}.dmg"
mkdir -p "$BUILD_DIR"

if [ "$NOTARIZE" = true ]; then
    xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" &>/dev/null \
        || { echo "Error: notary profile '$NOTARY_PROFILE' missing. See header of this script."; exit 1; }
elif [ "$DMG_ONLY" = false ]; then
    echo "Error: --skip-notarize only allowed with --dmg-only."; exit 1
fi

if [ "$DMG_ONLY" = false ]; then
    command -v gh &>/dev/null || { echo "Error: gh not installed. brew install gh"; exit 1; }
    gh auth status &>/dev/null || { echo "Error: gh not authenticated. Run: gh auth login"; exit 1; }
    [ -z "$(git status --porcelain)" ] || { echo "Error: working tree dirty. Commit first."; exit 1; }
    if git ls-remote --exit-code --tags origin "$TAG" &>/dev/null && [ "$SKIP_TAG" = false ]; then
        echo "Error: tag ${TAG} already on origin. Bump MARKETING_VERSION or pass --no-tag."; exit 1
    fi
fi

echo "==> Releasing ${APP_NAME} ${TAG}"

# ──────────────────────────────────────────────────────────────────────
# Step 1: Build app
# ──────────────────────────────────────────────────────────────────────

if [ -z "$APP_PATH" ]; then
    [ -f "${ROOT}/${APP_NAME}/Config.swift" ] || { echo "Error: ${APP_NAME}/Config.swift missing (copy Config.swift.example)."; exit 1; }
    echo "==> Building (Release)..."
    rm -rf "${BUILD_DIR}/${APP_NAME}.xcarchive" "${BUILD_DIR}/export"
    xcodebuild -project "$PROJECT" -scheme "$APP_NAME" -configuration Release \
        -destination "generic/platform=macOS" -allowProvisioningUpdates \
        -archivePath "${BUILD_DIR}/${APP_NAME}.xcarchive" -quiet archive
    xcodebuild -exportArchive -allowProvisioningUpdates \
        -archivePath "${BUILD_DIR}/${APP_NAME}.xcarchive" \
        -exportOptionsPlist "${SCRIPT_DIR}/ExportOptions.plist" \
        -exportPath "${BUILD_DIR}/export" -quiet
    APP_PATH="${BUILD_DIR}/export/${APP_NAME}.app"
fi
[ -d "$APP_PATH" ] || { echo "Error: app not found at $APP_PATH"; exit 1; }

BACKGROUND_PNG="${SCRIPT_DIR}/dmg-background.png"

# ──────────────────────────────────────────────────────────────────────
# Step 2: Build professional DMG
# ──────────────────────────────────────────────────────────────────────

echo "==> Building DMG..."

STAGING=$(mktemp -d)
DMG_RW=$(mktemp /tmp/dmg_rw_XXXXXX.dmg)
rm -f "$DMG_RW"  # hdiutil needs the path to not exist

# Stage app + Applications symlink
cp -R "$APP_PATH" "${STAGING}/${APP_NAME}.app"
ln -s /Applications "${STAGING}/Applications"

# Create writable DMG
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov -format UDRW -size 20m \
    "$DMG_RW" -quiet

# Detach any leftover mounts of same volume name
hdiutil detach "/Volumes/${APP_NAME}" 2>/dev/null || true

# Mount writable DMG
MOUNT_OUT=$(hdiutil attach "$DMG_RW" -readwrite -noverify -noautoopen)
MOUNT_POINT="/Volumes/${APP_NAME}"

if [ ! -d "$MOUNT_POINT" ]; then
    echo "Error: Failed to mount DMG at $MOUNT_POINT"
    exit 1
fi

# Add background
mkdir -p "${MOUNT_POINT}/.background"
cp "$BACKGROUND_PNG" "${MOUNT_POINT}/.background/background.png"

# Set volume icon from app icon (if available)
ICON_CANDIDATES=(
    "${APP_PATH}/Contents/Resources/AppIcon.icns"
    "${SCRIPT_DIR}/../BetterMSFile/Assets.xcassets/AppIcon.appiconset/icon_512x512.png"
)
for icon in "${ICON_CANDIDATES[@]}"; do
    if [ -f "$icon" ]; then
        cp "$icon" "${MOUNT_POINT}/.VolumeIcon.icns" 2>/dev/null || true
        break
    fi
done

# Configure Finder window via AppleScript
echo "==> Configuring Finder layout..."
osascript << APPLESCRIPT
tell application "Finder"
    tell disk "$APP_NAME"
        open
        delay 1

        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 760, 500}

        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 100
        set text size of viewOptions to 13
        set background picture of viewOptions to file ".background:background.png"

        -- App on left, Applications on right
        set position of item "${APP_NAME}.app" of container window to {160, 190}
        set position of item "Applications" of container window to {500, 190}

        close
        open
        delay 1
        close
    end tell
end tell
APPLESCRIPT

sync

# Detach & convert to compressed read-only
echo "==> Compressing DMG..."
hdiutil detach "$MOUNT_POINT" -quiet
rm -f "$DMG_NAME"
hdiutil convert "$DMG_RW" -format UDZO -imagekey zlib-level=9 -o "$DMG_NAME" -quiet

# Clean up temp files
rm -rf "$STAGING" "$DMG_RW"

DMG_SIZE=$(du -h "$DMG_NAME" | cut -f1)
echo "    Created ${DMG_NAME} (${DMG_SIZE})"

# Verify DMG contents
echo "==> Verifying DMG..."
hdiutil attach "$DMG_NAME" -nobrowse -quiet
VERIFY_OK=true
if [ ! -d "/Volumes/${APP_NAME}/${APP_NAME}.app" ]; then
    echo "    ERROR: ${APP_NAME}.app not found in DMG!"
    VERIFY_OK=false
fi
if [ ! -L "/Volumes/${APP_NAME}/Applications" ]; then
    echo "    ERROR: Applications symlink not found in DMG!"
    VERIFY_OK=false
fi
if [ ! -f "/Volumes/${APP_NAME}/.background/background.png" ]; then
    echo "    WARNING: Background image not found (cosmetic only)"
fi
hdiutil detach "/Volumes/${APP_NAME}" -quiet

if [ "$VERIFY_OK" = false ]; then
    echo "Error: DMG verification failed!"
    exit 1
fi
echo "    ✓ DMG verified: ${APP_NAME}.app + Applications symlink"

if [ "$NOTARIZE" = true ]; then
    echo "==> Signing & notarizing DMG (takes a few minutes)..."
    codesign --sign "Developer ID Application" --timestamp "$DMG_NAME"
    xcrun notarytool submit "$DMG_NAME" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG_NAME"
    spctl -a -t open --context context:primary-signature -v "$DMG_NAME"
fi

if [ "$DMG_ONLY" = true ]; then
    echo ""
    echo "==> DMG-only mode — skipping tag & release."
    echo "    DMG: ${DMG_NAME}"
    exit 0
fi

# ──────────────────────────────────────────────────────────────────────
# Step 3: Git tag
# ──────────────────────────────────────────────────────────────────────

if [ "$SKIP_TAG" = false ]; then
    echo "==> Tagging ${TAG}..."
    if git rev-parse "$TAG" &>/dev/null; then
        echo "    Tag ${TAG} already exists, skipping."
    else
        git tag "$TAG"
        git push origin "$TAG"
        echo "    Tag ${TAG} pushed."
    fi
else
    echo "==> Skipping tag (--no-tag)."
fi

# ──────────────────────────────────────────────────────────────────────
# Step 4: GitHub release
# ──────────────────────────────────────────────────────────────────────

echo "==> Creating GitHub release..."

RELEASE_ARGS=(
    "$TAG"
    "$DMG_NAME"
    --repo "$REPO"
    --title "${APP_NAME} ${TAG}"
)

if [ -n "$NOTES_FILE" ]; then
    RELEASE_ARGS+=(-F "$NOTES_FILE")
else
    RELEASE_ARGS+=(--generate-notes)
fi

gh release create "${RELEASE_ARGS[@]}"

RELEASE_URL="https://github.com/${REPO}/releases/tag/${TAG}"
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ✓ Release published!                    ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  ${RELEASE_URL}"
echo ""
echo "  DMG contains:"
echo "    • ${APP_NAME}.app  (drag to install)"
echo "    • Applications shortcut"
echo "    • Background with install instructions"
