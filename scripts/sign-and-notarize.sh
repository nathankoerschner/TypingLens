#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/release-common.sh"

require_env APPLE_DEVELOPER_ID
require_env APPLE_TEAM_ID
require_env APPLE_APP_SPECIFIC_PASSWORD

[[ -d "$APP_PATH" ]] || { echo "error: app not found at $APP_PATH" >&2; exit 1; }

# If the app is not already signed, attempt to sign it before notarization.
if ! codesign --verify --deep --strict --verbose=2 "$APP_PATH" >/dev/null 2>&1; then
  if [[ -z "${APPLE_SIGNING_IDENTITY:-}" ]]; then
    echo "error: app is unsigned and APPLE_SIGNING_IDENTITY is not set" >&2
    exit 1
  fi

  echo "info: signing app with identity ${APPLE_SIGNING_IDENTITY}"
  codesign --force --options runtime --timestamp --sign "$APPLE_SIGNING_IDENTITY" "$APP_PATH"
fi

/usr/bin/ditto -c -k --keepParent "$APP_PATH" "$APP_ZIP_PATH"

submission_output="$BUILD_DIR/notarytool-submit.log"
set +e
xcrun notarytool submit "$APP_ZIP_PATH" \
  --apple-id "$APPLE_DEVELOPER_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD" \
  --team-id "$APPLE_TEAM_ID" \
  --wait 2>&1 | tee "$submission_output"
submission_status=${PIPESTATUS[0]}
set -e

if (( submission_status != 0 )); then
  request_id="$(awk '/Request ID/ {print $NF}' "$submission_output" | tail -n 1)"
  if [[ -n "$request_id" ]]; then
    xcrun notarytool log "$request_id" \
      --apple-id "$APPLE_DEVELOPER_ID" \
      --password "$APPLE_APP_SPECIFIC_PASSWORD" \
      --team-id "$APPLE_TEAM_ID" || true
  fi
  echo "error: notarization submission failed" >&2
  exit "$submission_status"
fi

xcrun stapler staple "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl --assess --type execute --verbose "$APP_PATH"
