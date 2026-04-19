#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/release-common.sh"

mkdir -p "$BUILD_DIR"
rm -rf "$ARCHIVE_PATH"
rm -rf "$EXPORT_DIR"
rm -f "$BUILD_DIR"/*.dmg
rm -f "$BUILD_DIR"/*.zip

TEMPLATE_EXPORT_OPTIONS="$ROOT_DIR/TypingLens/ExportOptions-DeveloperID.plist"
GENERATED_EXPORT_OPTIONS="$BUILD_DIR/ExportOptions-DeveloperID.generated.plist"

if [[ ! -f "$TEMPLATE_EXPORT_OPTIONS" ]]; then
  echo "error: missing export options file: $TEMPLATE_EXPORT_OPTIONS" >&2
  exit 1
fi

if [[ -n "${APPLE_TEAM_ID:-}" ]]; then
  sed "s/__APPLE_TEAM_ID__/${APPLE_TEAM_ID}/g" "$TEMPLATE_EXPORT_OPTIONS" > "$GENERATED_EXPORT_OPTIONS"
else
  cp "$TEMPLATE_EXPORT_OPTIONS" "$GENERATED_EXPORT_OPTIONS"
fi

XCODEBUILD_ARGS=(
  -project "$ROOT_DIR/TypingLens.xcodeproj"
  -scheme TypingLens
  -configuration Release
  -destination 'generic/platform=macOS'
  -archivePath "$ARCHIVE_PATH"
  ARCHS=arm64
  ONLY_ACTIVE_ARCH=NO
)

if [[ -n "${APPLE_TEAM_ID:-}" ]]; then
  XCODEBUILD_ARGS+=(DEVELOPMENT_TEAM="$APPLE_TEAM_ID")
fi

if [[ -n "${VERSION:-}" ]]; then
  XCODEBUILD_ARGS+=(MARKETING_VERSION="$VERSION")
fi

if [[ -n "${APPLE_SIGNING_IDENTITY:-}" ]]; then
  XCODEBUILD_ARGS+=(CODE_SIGN_IDENTITY="$APPLE_SIGNING_IDENTITY")
fi

if [[ -n "${KEYCHAIN_PATH:-}" ]]; then
  XCODEBUILD_ARGS+=(OTHER_CODE_SIGN_FLAGS="--keychain $KEYCHAIN_PATH")
fi

xcodebuild archive "${XCODEBUILD_ARGS[@]}"

EXPORT_ARGS=(
  -archivePath "$ARCHIVE_PATH"
  -exportPath "$EXPORT_DIR"
  -exportOptionsPlist "$GENERATED_EXPORT_OPTIONS"
)

if [[ -n "${KEYCHAIN_PATH:-}" ]]; then
  EXPORT_ARGS+=(OTHER_CODE_SIGN_FLAGS="--keychain $KEYCHAIN_PATH")
fi

xcodebuild -exportArchive "${EXPORT_ARGS[@]}"

[[ -d "$APP_PATH" ]] || { echo "error: exported app not found at $APP_PATH" >&2; exit 1; }

write_manifest
