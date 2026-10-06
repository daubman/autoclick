#!/bin/zsh
# Builds build/Autoclick.app (universal: Apple silicon and Intel) and build/Autoclick.zip.
#
#   scripts/build-app.sh [version]
#
# The version defaults to the latest git tag (v1.2.3 -> 1.2.3), or 0.0.0-dev.
set -euo pipefail
cd "${0:a:h}/.."

VERSION="${1:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)}"
VERSION="${VERSION:-0.0.0-dev}"
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Autoclick"

APP=build/Autoclick.app
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Autoclick"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NUMBER/" Resources/Info.plist > "$APP/Contents/Info.plist"

# Ad-hoc signature. macOS ties permissions to the signature, so every rebuild needs them granted
# again. Set CODESIGN_IDENTITY to a Developer ID to sign properly.
codesign --force --options runtime --sign "${CODESIGN_IDENTITY:--}" "$APP"

ditto -c -k --keepParent "$APP" build/Autoclick.zip
echo "Built $(pwd)/$APP ($VERSION) and build/Autoclick.zip"
