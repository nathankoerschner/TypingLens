#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/release-common.sh"

require_env BUILD_CERTIFICATE_BASE64
require_env P12_PASSWORD
require_env KEYCHAIN_PASSWORD

CERT_PATH="${RUNNER_TEMP:-/tmp}/build_certificate.p12"
KEYCHAIN_PATH="${RUNNER_TEMP:-/tmp}/typinglens-signing.keychain-db"
export KEYCHAIN_PATH

rm -f "$CERT_PATH"
rm -f "$KEYCHAIN_PATH"

echo "$BUILD_CERTIFICATE_BASE64" | base64 --decode > "$CERT_PATH"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -l -u "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security import "$CERT_PATH" -P "$P12_PASSWORD" -A -f pkcs12 -k "$KEYCHAIN_PATH"
security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security list-keychains -d user -s "$KEYCHAIN_PATH"
security default-keychain -s "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security find-identity -v -p codesigning "$KEYCHAIN_PATH"

DETECTED_SIGNING_IDENTITY="$(security find-identity -v -p codesigning "$KEYCHAIN_PATH" | awk -F'"' '/Mac Developer ID Application:|Developer ID Application:/ { print $2; exit }')"

if [[ -z "$DETECTED_SIGNING_IDENTITY" ]]; then
  echo "error: could not detect Developer ID signing identity in $KEYCHAIN_PATH" >&2
  exit 1
fi

trimmed_team_id="$(printf '%s' "${APPLE_TEAM_ID:-}" | tr -d '[:space:]')"
DETECTED_TEAM_ID="$(security find-certificate -c "$DETECTED_SIGNING_IDENTITY" -p "$KEYCHAIN_PATH" \
  | openssl x509 -noout -subject -nameopt RFC2253 \
  | sed -n 's/.*OU=\([^,]*\).*/\1/p' \
  | head -n 1)"

if [[ -z "$DETECTED_TEAM_ID" ]]; then
  echo "error: could not detect Apple team ID from signing certificate: $DETECTED_SIGNING_IDENTITY" >&2
  exit 1
fi

if [[ -n "$trimmed_team_id" && "$trimmed_team_id" != "$DETECTED_TEAM_ID" ]]; then
  echo "warning: APPLE_TEAM_ID did not match the imported signing certificate; using certificate team ID instead" >&2
fi

if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "KEYCHAIN_PATH=$KEYCHAIN_PATH" >> "$GITHUB_ENV"
  echo "APPLE_SIGNING_IDENTITY=$DETECTED_SIGNING_IDENTITY" >> "$GITHUB_ENV"
  echo "APPLE_TEAM_ID=$DETECTED_TEAM_ID" >> "$GITHUB_ENV"
fi

rm -f "$CERT_PATH"
