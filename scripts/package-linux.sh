#!/usr/bin/env bash
# Build a self-contained Linux release tarball (used by .github/workflows/release.yml).
#
#   ./scripts/package-linux.sh v1.9   ->  build/BetterMSFile-v1.9-linux-<arch>.tar.gz
#
# The tarball holds the binary plus the Swift runtime libraries it links (users don't need Swift),
# the icon and install.sh (= install-linux.sh, which installs the prebuilt files).
# GTK 4 / libadwaita come from the system. Needs patchelf.
set -euo pipefail

TAG="${1:?usage: package-linux.sh <tag, e.g. v1.9>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME="BetterMSFile-${TAG}-linux-$(uname -m)"
STAGE="$ROOT/build/$NAME"

swift build -c release --package-path "$ROOT"
BIN="$ROOT/.build/release/bettermsfile"

rm -rf "$STAGE" && mkdir -p "$STAGE"
cp "$BIN" "$STAGE/bettermsfile"
# Bundle the Swift runtime (everything ldd resolves from the toolchain) and load it from the binary's folder only.
SWIFT_LIBS=$(ldd "$BIN" | awk '/\/swift\// {print $3}')
[[ -n "$SWIFT_LIBS" ]] || { echo "error: no Swift runtime libraries found via ldd" >&2; exit 1; }
cp $SWIFT_LIBS "$STAGE/"
patchelf --set-rpath '$ORIGIN' "$STAGE/bettermsfile"
cp "$ROOT/scripts/install-linux.sh" "$STAGE/install.sh"
cp "$ROOT/design/icon.svg" "$STAGE/icon.svg"
cp "$ROOT/README.md" "$STAGE/README.md"

# Fail the release if anything is still unresolved inside the bundle (system libs like GTK are fine).
if ldd "$STAGE/bettermsfile" | grep -q "/usr/lib/swift/"; then
    echo "error: binary still loads the toolchain's Swift runtime" >&2; exit 1
fi

tar -C "$ROOT/build" -czf "$ROOT/build/$NAME.tar.gz" "$NAME"
echo "$ROOT/build/$NAME.tar.gz"
