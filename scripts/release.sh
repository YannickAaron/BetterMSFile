#!/bin/bash
set -euo pipefail

# BetterMSFile Release Script
# Creates a DMG from a .app bundle and publishes a GitHub release.
#
# Usage: ./scripts/release.sh <version> <path-to-app>
# Example: ./scripts/release.sh 1.3 ./build/BetterMSFile.app

APP_NAME="BetterMSFile"
REPO="YannickAaron/BetterMSFile"

# --- Validate inputs ---

if [ $# -lt 2 ]; then
    echo "Usage: $0 <version> <path-to-.app>"
    echo "Example: $0 1.3 ./build/BetterMSFile.app"
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

# Check for required tools
if ! command -v gh &>/dev/null; then
    echo "Error: GitHub CLI (gh) is not installed. Install with: brew install gh"
    exit 1
fi

if ! gh auth status &>/dev/null; then
    echo "Error: GitHub CLI is not authenticated. Run: gh auth login"
    exit 1
fi

TAG="v${VERSION}"
DMG_NAME="${APP_NAME}-${TAG}.dmg"

echo "==> Building release ${TAG}"
echo "    App: ${APP_PATH}"
echo "    DMG: ${DMG_NAME}"
echo ""

# --- Create DMG ---

echo "==> Creating DMG..."
TEMP_DIR=$(mktemp -d)
cp -R "$APP_PATH" "${TEMP_DIR}/${APP_NAME}.app"
ln -s /Applications "${TEMP_DIR}/Applications"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$TEMP_DIR" \
    -ov \
    -format UDZO \
    "$DMG_NAME" \
    -quiet

rm -rf "$TEMP_DIR"
echo "    Created ${DMG_NAME} ($(du -h "$DMG_NAME" | cut -f1))"

# --- Create git tag ---

echo "==> Tagging ${TAG}..."
if git rev-parse "$TAG" &>/dev/null; then
    echo "    Tag ${TAG} already exists, skipping tag creation."
else
    git tag "$TAG"
    git push origin "$TAG"
    echo "    Tag ${TAG} pushed."
fi

# --- Create GitHub release ---

echo "==> Creating GitHub release..."
gh release create "$TAG" \
    "$DMG_NAME" \
    --repo "$REPO" \
    --title "${APP_NAME} ${TAG}" \
    --generate-notes

RELEASE_URL="https://github.com/${REPO}/releases/tag/${TAG}"
echo ""
echo "==> Release published!"
echo "    ${RELEASE_URL}"
echo ""
echo "Reminder: Make sure MARKETING_VERSION in Xcode matches '${VERSION}' before building."
