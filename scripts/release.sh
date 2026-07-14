#!/usr/bin/env bash
#
# Build, sign, package, notarize, and staple Ivan's Menu into a distributable DMG.
#
# One-time setup (do this once, it is stored in your login keychain):
#
#   1. Create an app-specific password at https://appleid.apple.com
#      (Sign in > App-Specific Passwords > generate one, label it "notary").
#
#   2. Store the notary credentials under a profile name:
#
#        xcrun notarytool store-credentials "ivans-menu-notary" \
#          --apple-id "you@example.com" \
#          --team-id "347LA37C2B" \
#          --password "abcd-efgh-ijkl-mnop"   # the app-specific password
#
# Then every release is just:
#
#   DEVELOPER_ID="Developer ID Application: Ivan Kuria (347LA37C2B)" ./scripts/release.sh
#
set -euo pipefail
cd "$(dirname "$0")/.."

APP="IvansMenu.app"
VOL="Ivan's Menu"
DMG="IvansMenu.dmg"
NOTARY_PROFILE="${NOTARY_PROFILE:-ivans-menu-notary}"

if [ -z "${DEVELOPER_ID:-}" ]; then
  echo "error: set DEVELOPER_ID to your Developer ID Application identity." >&2
  echo "       e.g. DEVELOPER_ID=\"Developer ID Application: Ivan Kuria (347LA37C2B)\"" >&2
  exit 1
fi

echo "==> Building and signing $APP"
DEVELOPER_ID="$DEVELOPER_ID" ./scripts/bundle.sh

echo "==> Building $DMG"
rm -f "$DMG"
create-dmg \
  --volname "$VOL" \
  --window-size 540 380 \
  --icon-size 110 \
  --icon "$APP" 150 180 \
  --app-drop-link 390 180 \
  --no-internet-enable \
  "$DMG" "$APP" >/dev/null

echo "==> Signing $DMG"
codesign --force --timestamp --sign "$DEVELOPER_ID" "$DMG"

echo "==> Submitting to Apple notary service (this can take a few minutes)"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling the notarization ticket"
xcrun stapler staple "$DMG"

echo "==> Verifying Gatekeeper acceptance"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG" || true
xcrun stapler validate "$DMG"

echo "==> Done: $DMG is signed, notarized, and stapled."
