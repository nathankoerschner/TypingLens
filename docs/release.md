# TypingLens Release Process

## Required environment variables

```bash
export APPLE_DEVELOPER_ID="developer@example.com"
export APPLE_TEAM_ID="ABCDE12345"
export APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
export BUILD_CERTIFICATE_BASE64="..."
export P12_PASSWORD="..."
export KEYCHAIN_PASSWORD="..."
export APPLE_SIGNING_IDENTITY="Developer ID Application: <Name> (<TEAM_ID>)" # optional for local signing
```

`APPLE_SIGNING_IDENTITY` is optional when building on a machine that already has the app signed by another step. The automated scripts require a signed app before notarization.

## Local release steps

```bash
./scripts/build-app.sh
./scripts/sign-and-notarize.sh   # requires Apple credentials and a local signing identity
./scripts/create-dmg.sh
```

## Output

- `build/release/export/TypingLens.app`
- `build/release/TypingLens-<version>.dmg`

## Locally available helpers

- `scripts/build-app.sh`
  - Creates `build/release/TypingLens.xcarchive`
  - Exports `build/release/export/TypingLens.app`
  - Writes `build/release/release-manifest.json`
- `scripts/sign-and-notarize.sh`
  - Signs (if needed), notarizes, staples, and verifies the app
- `scripts/create-dmg.sh`
  - Builds a deterministic `UDZO` DMG with an `Applications` alias

## Troubleshooting

### Notarytool validation failures

Re-run notarization submission with logs enabled and inspect:

```bash
xcrun notarytool log <REQUEST_ID> \
  --apple-id "$APPLE_DEVELOPER_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD" \
  --team-id "$APPLE_TEAM_ID"
```

Check that all required entitlements, Info.plist keys, and signing identity values are present.

### Common local issues

- **`error: missing required env var`**
  - Ensure every required variable is exported in your shell before running the scripts.
- **`codesign --verify` failures**
  - Confirm your `APPLE_SIGNING_IDENTITY` matches an installed Developer ID certificate:
    ```bash
    security find-identity -v -p codesigning
    ```
- **`xcodebuild` fails while building the scheme**
  - Ensure the Xcode project is generated and no local workspace/product ignores block it from source control.
