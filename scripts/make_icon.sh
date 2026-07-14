#!/usr/bin/env bash
# Renders the app icon and packs it into Sources/IvansMenu/Resources/AppIcon.icns
set -euo pipefail
cd "$(dirname "$0")/.."

WORK="scripts/build"
ICONSET="$WORK/AppIcon.iconset"
BASE="$WORK/icon_1024.png"
OUT="Sources/IvansMenu/Resources/AppIcon.icns"

rm -rf "$ICONSET"; mkdir -p "$ICONSET"

# 1. Render the 1024 master from the Swift drawing.
swift scripts/make_icon.swift "$BASE"

# 2. Downscale to every size macOS wants.
gen() { sips -z "$2" "$2" "$BASE" --out "$ICONSET/$1" >/dev/null; }
gen icon_16x16.png 16
gen icon_16x16@2x.png 32
gen icon_32x32.png 32
gen icon_32x32@2x.png 64
gen icon_128x128.png 128
gen icon_128x128@2x.png 256
gen icon_256x256.png 256
gen icon_256x256@2x.png 512
gen icon_512x512.png 512
cp "$BASE" "$ICONSET/icon_512x512@2x.png"

# 3. Pack into .icns.
iconutil -c icns "$ICONSET" -o "$OUT"
echo "Wrote $OUT"
