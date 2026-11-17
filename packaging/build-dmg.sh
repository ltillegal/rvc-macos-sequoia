#!/usr/bin/env bash
#
# Builds a drag-to-Applications .dmg with the "RVC WebUI" launcher app.
#
#   ./packaging/build-dmg.sh --version 0.1.0
#
# The resulting .app embeds the repository sources (Resources/app). On first
# launch the launcher copies them into ~/Library/Application Support/RVC-WebUI,
# so the .dmg is only needed for the initial install.
#
# Signing and notarization (both off by default):
#   RVC_CODESIGN_IDENTITY   "Developer ID Application: Name (TEAMID)"; when set,
#                           the app is signed with the hardened runtime and the
#                           result is notarized with notarytool.
#   RVC_NOTARY_PROFILE      keychain profile created by
#                           `xcrun notarytool store-credentials`; used instead of
#                           the APPLE_ID credentials below.
#   APPLE_ID, APPLE_TEAM_ID, APPLE_APP_PASSWORD
#                           Apple ID + team + app-specific password, used when no
#                           keychain profile is given.
# Without RVC_CODESIGN_IDENTITY the bundle is ad-hoc signed, which is enough for
# local use but triggers Gatekeeper on other Macs.
#
set -euo pipefail

VERSION="0.1.0"
OUT="dist"

while [ $# -gt 0 ]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --out)     OUT="$2";     shift 2 ;;
    -h|--help) sed -n '2,23p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="RVC WebUI"
STAGE="$OUT/staging"
BUNDLE="$STAGE/$APP_NAME.app"
DMG="$OUT/RVC-WebUI-${VERSION}-macos.dmg"

echo "==> version $VERSION"
echo "==> staging in $STAGE"
rm -rf "$STAGE" "$DMG"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"

# 1. Launcher
sed "s/__VERSION__/${VERSION}/" "$ROOT/packaging/launcher.sh" > "$BUNDLE/Contents/MacOS/RVCWebUI"
chmod +x "$BUNDLE/Contents/MacOS/RVCWebUI"

# 2. Info.plist
cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>io.github.ltillegal.rvc-webui</string>
  <key>CFBundleExecutable</key><string>RVCWebUI</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>CFBundleIconFile</key><string>icon</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.music</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
</dict>
</plist>
PLIST

# 3. Sources
# The bundle only needs what the app runs: development files (tests, CI,
# packaging, the plan) and the translations that no code reads are left out.
echo "==> embedding sources"
mkdir -p "$BUNDLE/Contents/Resources/app"
rsync -a \
  --exclude '.git' \
  --exclude '.venv' \
  --exclude 'dist' \
  --exclude '__pycache__' \
  --exclude '.env' \
  --exclude 'logs' \
  --exclude 'plan.md' \
  --exclude 'tests' \
  --exclude 'colab' \
  --exclude '*.ipynb' \
  --exclude '.github' \
  --exclude 'packaging' \
  --exclude 'docs/cn' \
  --exclude 'docs/jp' \
  --exclude 'docs/kr' \
  --exclude 'docs/fr' \
  --exclude 'docs/pt' \
  --exclude 'docs/tr' \
  --exclude 'docs/*.doc' \
  "$ROOT/" "$BUNDLE/Contents/Resources/app/"
chmod +x "$BUNDLE/Contents/Resources/app/tools/dlmodels.sh" 2>/dev/null || true

# 4. Icon (optional)
if [ -f "$ROOT/packaging/icon.icns" ]; then
  cp "$ROOT/packaging/icon.icns" "$BUNDLE/Contents/Resources/icon.icns"
fi

# 5. Sign. Ad-hoc by default: unsigned arm64 bundles are rejected by Gatekeeper
#    even after the quarantine bit is cleared, and ad-hoc is enough for that. No
#    nested code here, so no --deep. With a Developer ID the hardened runtime is
#    required for notarization, and the ticket is stapled so Gatekeeper accepts
#    the app without a network round-trip.
IDENTITY="${RVC_CODESIGN_IDENTITY:--}"
NOTARIZE=0
if [ "$IDENTITY" != "-" ]; then
  echo "==> signing with $IDENTITY"
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$BUNDLE"
  codesign --verify --strict "$BUNDLE"
  NOTARIZE=1
else
  echo "==> signing (ad-hoc)"
  codesign --force --sign - "$BUNDLE" >/dev/null 2>&1 || echo "   warning: codesign failed"
  codesign --verify --deep --strict "$BUNDLE" 2>/dev/null && echo "   signature ok"
fi

notarize() {
  if [ -n "${RVC_NOTARY_PROFILE:-}" ]; then
    xcrun notarytool submit "$1" --keychain-profile "$RVC_NOTARY_PROFILE" --wait
  else
    : "${APPLE_ID:?set RVC_NOTARY_PROFILE, or APPLE_ID/APPLE_TEAM_ID/APPLE_APP_PASSWORD}"
    : "${APPLE_TEAM_ID:?set APPLE_TEAM_ID}"
    : "${APPLE_APP_PASSWORD:?set APPLE_APP_PASSWORD}"
    xcrun notarytool submit "$1" \
      --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" \
      --password "$APPLE_APP_PASSWORD" --wait
  fi
}

# 6. Notarize the app before the staging directory goes away: stapling the
#    ticket into the bundle is what lets the copy in /Applications launch
#    without an online Gatekeeper check.
if [ "$NOTARIZE" = "1" ]; then
  ZIP="$OUT/RVC-WebUI-${VERSION}-macos.zip"
  echo "==> notarizing the app"
  /usr/bin/ditto -c -k --keepParent "$BUNDLE" "$ZIP"
  notarize "$ZIP"
  rm -f "$ZIP"
  xcrun stapler staple "$BUNDLE"
  xcrun stapler validate "$BUNDLE"
fi

# 7. DMG
ln -s /Applications "$STAGE/Applications"
echo "==> building dmg"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

if [ "$NOTARIZE" = "1" ]; then
  echo "==> notarizing the dmg"
  codesign --force --timestamp --sign "$IDENTITY" "$DMG"
  notarize "$DMG"
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
else
  echo "==> not notarized (set RVC_CODESIGN_IDENTITY to notarize)"
fi

SIZE=$(du -h "$DMG" | cut -f1)
echo "==> $DMG ($SIZE)"
# Write the basename so `shasum -a 256 -c` works from the download directory.
( cd "$OUT" && shasum -a 256 "$(basename "$DMG")" ) | tee "$DMG.sha256"
