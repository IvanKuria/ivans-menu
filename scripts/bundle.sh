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

if [ -n "${DEVELOPER_ID:-}" ]; then
  codesign --deep --force --options runtime \
    --sign "$DEVELOPER_ID" "$APP"
  echo "Signed with $DEVELOPER_ID"
else
  echo "Set DEVELOPER_ID to code-sign (e.g. 'Developer ID Application: Name (TEAMID)')."
fi
echo "Built $APP"
