#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/release-common.sh"

VERSION="${VERSION:-$(current_version)}"
DMG_PATH="$BUILD_DIR/TypingLens-${VERSION}.dmg"

[[ -d "$APP_PATH" ]] || { echo "error: app not found at $APP_PATH" >&2; exit 1; }
assert_camera_usage_description "$APP_PATH"

rm -rf "$DMG_STAGING_DIR"
mkdir -p "$DMG_STAGING_DIR"
cp -R "$APP_PATH" "$DMG_STAGING_DIR/TypingLens.app"
assert_camera_usage_description "$DMG_STAGING_DIR/TypingLens.app"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

hdiutil create \
  -volname "TypingLens" \
  -srcfolder "$DMG_STAGING_DIR" \
  -ov -format UDZO \
  "$DMG_PATH"

codesign --verify --verbose=2 "$DMG_PATH" || true
