#!/bin/bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────
# BetterMSFile Release Script
# Creates a professional DMG (background + Applications shortcut +
# icon layout) and publishes a GitHub release.
#
# Usage:  ./scripts/release.sh <version> <path-to-app>
# Example: ./scripts/release.sh 1.65 ./BetterMSFileV1.65.app
#
# Options:
#   --dmg-only    Build the DMG but skip tagging & GitHub release
#   --no-tag      Skip git tag creation (use when tag already exists)
#   --notes FILE  Read release notes from FILE instead of --generate-notes
# ──────────────────────────────────────────────────────────────────────

APP_NAME="BetterMSFile"
REPO="YannickAaron/BetterMSFile"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Parse flags ---
DMG_ONLY=false
SKIP_TAG=false
NOTES_FILE=""

POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dmg-only)  DMG_ONLY=true; shift ;;
        --no-tag)    SKIP_TAG=true; shift ;;
        --notes)     NOTES_FILE="$2"; shift 2 ;;
        *)           POSITIONAL+=("$1"); shift ;;
    esac
done
set -- "${POSITIONAL[@]}"

# --- Validate inputs ---

if [ $# -lt 2 ]; then
    echo "Usage: $0 [--dmg-only] [--no-tag] [--notes FILE] <version> <path-to-.app>"
    echo ""
    echo "Examples:"
    echo "  $0 1.65 ./BetterMSFileV1.65.app"
    echo "  $0 --dmg-only 1.65 ./BetterMSFileV1.65.app"
    echo "  $0 --notes release-notes.md 1.65 ./BetterMSFileV1.65.app"
    exit 1
fi

VERSION="$1"
APP_PATH="$2"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: '$APP_PATH' does not exist or is not a directory."
    exit 1
fi

if [[ ! "$APP_PATH" == *.app ]]; then
    echo "Error: '$APP_PATH' does not look like a .app bundle."
    exit 1
fi

if [ "$DMG_ONLY" = false ]; then
    if ! command -v gh &>/dev/null; then
        echo "Error: GitHub CLI (gh) is not installed. Install with: brew install gh"
        exit 1
    fi
    if ! gh auth status &>/dev/null; then
        echo "Error: GitHub CLI is not authenticated. Run: gh auth login"
        exit 1
    fi
fi

if ! command -v python3 &>/dev/null; then
    echo "Error: python3 is required for background image generation."
    exit 1
fi

TAG="v${VERSION}"
DMG_NAME="${APP_NAME}-${TAG}.dmg"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  BetterMSFile Release Builder            ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  Version:  ${TAG}"
echo "  App:      ${APP_PATH}"
echo "  DMG:      ${DMG_NAME}"
echo "  DMG-only: ${DMG_ONLY}"
echo ""

# ──────────────────────────────────────────────────────────────────────
# Step 1: Generate DMG background image
# ──────────────────────────────────────────────────────────────────────

echo "==> Generating DMG background image..."

BACKGROUND_PNG=$(mktemp /tmp/dmg_bg_XXXXXX.png)

python3 - "$BACKGROUND_PNG" << 'PYEOF'
import sys
try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Error: Pillow is not installed. Run: pip3 install Pillow", file=sys.stderr)
    sys.exit(1)

output_path = sys.argv[1]

WIDTH, HEIGHT = 660, 400
BG = (30, 30, 32)
ARROW = (120, 120, 125)
TEXT = (180, 180, 185)
SUBTLE = (130, 130, 135)

img = Image.new("RGBA", (WIDTH, HEIGHT), BG)
draw = ImageDraw.Draw(img)

# Subtle gradient at top
for y in range(80):
    a = int(40 * (1 - y / 80))
    draw.line([(0, y), (WIDTH, y)], fill=(255, 255, 255, a))

# Arrow — center of image
cx, cy = WIDTH // 2, HEIGHT // 2 - 10
shaft_w, shaft_h = 80, 8
draw.rounded_rectangle(
    [cx - shaft_w//2, cy - shaft_h//2, cx + shaft_w//2, cy + shaft_h//2],
    radius=4, fill=ARROW
)
head = 24
draw.polygon([
    (cx + shaft_w//2 - 2, cy - head),
    (cx + shaft_w//2 + head + 6, cy),
    (cx + shaft_w//2 - 2, cy + head),
], fill=ARROW)

# Load fonts
for path in ["/System/Library/Fonts/SFCompact.ttf",
             "/System/Library/Fonts/Helvetica.ttc",
             "/System/Library/Fonts/HelveticaNeue.ttc"]:
    try:
        font = ImageFont.truetype(path, 15)
        font_sm = ImageFont.truetype(path, 12)
        break
    except Exception:
        continue
else:
    font = ImageFont.load_default()
    font_sm = font

# "Drag to Applications to install"
label = "Drag to Applications to install"
bb = draw.textbbox((0, 0), label, font=font)
draw.text(((WIDTH - (bb[2] - bb[0])) // 2, cy + 40), label, fill=TEXT, font=font)

# Zone labels
for text, x_center in [("BetterMSFile", WIDTH // 4), ("Applications", 3 * WIDTH // 4)]:
    bb = draw.textbbox((0, 0), text, font=font_sm)
    draw.text((x_center - (bb[2] - bb[0]) // 2, HEIGHT - 60), text, fill=SUBTLE, font=font_sm)

# Bottom rule
draw.line([(40, HEIGHT - 30), (WIDTH - 40, HEIGHT - 30)], fill=(60, 60, 65), width=1)

img.save(output_path, "PNG")
print(f"    Background: {output_path} ({WIDTH}x{HEIGHT})")
PYEOF

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
rm -rf "$STAGING" "$DMG_RW" "$BACKGROUND_PNG"

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

if [ "$DMG_ONLY" = true ]; then
    echo ""
    echo "==> DMG-only mode — skipping tag & release."
    echo "    DMG: $(pwd)/${DMG_NAME}"
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
echo ""
echo "Reminder: Ensure MARKETING_VERSION in Xcode matches '${VERSION}'."
