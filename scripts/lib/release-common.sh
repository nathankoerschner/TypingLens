#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build/release}"
ARCHIVE_PATH="$BUILD_DIR/TypingLens.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP_PATH="$EXPORT_DIR/TypingLens.app"
DMG_STAGING_DIR="$BUILD_DIR/dmg"

current_version() {
  local plist_path

  if [[ -f "$APP_PATH/Contents/Info.plist" ]]; then
    plist_path="$APP_PATH/Contents/Info.plist"
  elif [[ -f "$ARCHIVE_PATH/Products/Applications/TypingLens.app/Contents/Info.plist" ]]; then
    plist_path="$ARCHIVE_PATH/Products/Applications/TypingLens.app/Contents/Info.plist"
  else
    xcodebuild \
      -project "$ROOT_DIR/TypingLens.xcodeproj" \
      -scheme TypingLens \
      -showBuildSettings 2>/dev/null \
      | awk -F' = ' '/MARKETING_VERSION = / { print $2; exit }'
    return
  fi

  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist_path"
}

VERSION="${VERSION:-$(current_version)}"
DMG_PATH="$BUILD_DIR/TypingLens-${VERSION}.dmg"
APP_ZIP_PATH="$BUILD_DIR/TypingLens.zip"

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "error: missing required env var: ${name}" >&2
    exit 1
  fi
}

write_manifest() {
  local manifest_path="$BUILD_DIR/release-manifest.json"
  mkdir -p "$BUILD_DIR"

  cat > "$manifest_path" <<EOF
{
  "version": "${VERSION}",
  "app": "${APP_PATH}",
  "archive": "${ARCHIVE_PATH}"
}
EOF
}

cleanup_keychain() {
  if [[ -n "${KEYCHAIN_PATH:-}" && -f "$KEYCHAIN_PATH" ]]; then
    security delete-keychain "$KEYCHAIN_PATH" >/dev/null 2>&1 || true
    KEYCHAIN_PATH=""
  fi
}

register_keychain_cleanup() {
  trap cleanup_keychain EXIT
}
