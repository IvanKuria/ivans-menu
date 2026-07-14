#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
APP="IvansMenu.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Sources/IvansMenu/Info.plist "$APP/Contents/Info.plist"
cp .build/release/IvansMenu "$APP/Contents/MacOS/IvansMenu"

# App icon (CFBundleIconFile=AppIcon → Contents/Resources/AppIcon.icns).
if [ -f Sources/IvansMenu/Resources/AppIcon.icns ]; then
  cp Sources/IvansMenu/Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

# Copy SPM resource bundle if present
BUNDLE=$(find -L .build/release -maxdepth 1 -name "*IvansMenu*.bundle" | head -1 || true)
if [ -n "${BUNDLE:-}" ]; then cp -R "$BUNDLE" "$APP/Contents/Resources/"; fi

# For distribution (STRIP_THEME_ART=1), remove the real Wii art from the bundle
# so the shipped DMG hosts none of it. The app fetches the theme pack on first
# launch instead. Must run before signing so the signature stays valid.
if [ -n "${STRIP_THEME_ART:-}" ]; then
  find "$APP/Contents/Resources" -type d -path "*/Resources/Wii" -exec rm -rf {} + 2>/dev/null || true
  echo "Stripped bundled Wii art (distribution build; app fetches it at runtime)."
fi

if [ -n "${DEVELOPER_ID:-}" ]; then
  # Hardened runtime + secure timestamp are both required for notarization.
  codesign --deep --force --options runtime --timestamp \
    --sign "$DEVELOPER_ID" "$APP"
  codesign --verify --strict --verbose=2 "$APP"
  echo "Signed with $DEVELOPER_ID"
else
  echo "Set DEVELOPER_ID to code-sign (e.g. 'Developer ID Application: Name (TEAMID)')."
fi
echo "Built $APP"
