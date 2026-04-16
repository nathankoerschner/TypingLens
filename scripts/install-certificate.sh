#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/lib/release-common.sh"

require_env BUILD_CERTIFICATE_BASE64
require_env P12_PASSWORD
require_env KEYCHAIN_PASSWORD

CERT_PATH="${RUNNER_TEMP:-/tmp}/build_certificate.p12"
KEYCHAIN_PATH="${RUNNER_TEMP:-/tmp}/typinglens-signing.keychain-db"
export KEYCHAIN_PATH

# Ensure the temporary keychain is always cleaned up in CI.
register_keychain_cleanup

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

if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "KEYCHAIN_PATH=$KEYCHAIN_PATH" >> "$GITHUB_ENV"
fi

rm -f "$CERT_PATH"
