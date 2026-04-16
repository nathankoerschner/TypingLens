# TypingLens Release Design

## Goal

Bundle TypingLens so anyone can download and run it directly from the GitHub page using a standard macOS distribution flow.

## Distribution Strategy

TypingLens will be distributed via:

- **GitHub Releases** for end-user downloads
- **Signed + notarized `.dmg`** files for macOS distribution
- **GitHub Actions** for automation

## Platform Scope

- **macOS only**
- **Apple Silicon only**

## Packaging Format

The app will be distributed as a:

- **`.dmg` installer**

This is the standard polished format for downloadable Mac apps.

## App Project Structure

TypingLens currently builds as a Swift package, but it does not yet naturally produce a standard macOS `.app` bundle suitable for signing, notarization, and DMG packaging.

To support standard macOS release distribution, the project will adopt:

- a native **Xcode macOS app project** (`TypingLens.xcodeproj`)

This is the preferred approach because it makes the following much more standard and reliable:

- creation of a proper `.app` bundle
- bundle metadata management
- code signing
- notarization
- archive/export workflows
- future macOS distribution maintenance

## Bundle Identifier

The app bundle identifier will be:

- `io.typinglens.app`

## Signing and Notarization

The release build should be:

- **signed** with Apple Developer ID signing
- **notarized** using Apple notarization tools
- **stapled** after notarization

This provides the best user experience for direct downloads outside the Mac App Store.

## App Characteristics Relevant to Packaging

TypingLens appears to use:

- global keyboard monitoring
- Accessibility permission access
- menu bar app behavior

Because of this, the macOS app target should be configured as a normal Developer ID distributed app rather than an App Store-style sandboxed app.

Recommended configuration:

- **App Sandbox disabled**
- Developer ID distribution
- permissions and app behavior preserved for menu bar utility usage

## CI/CD Behavior

### On push to `main`

GitHub Actions should:

1. build the app
2. sign the app
3. notarize the app
4. staple the notarization result
5. package the app into a `.dmg`
6. upload the `.dmg` as a **GitHub Actions artifact**

This provides downloadable CI artifacts for each push without cluttering the public Releases page.

### On version tags

For tags matching a version pattern such as `v*`, GitHub Actions should:

1. build the app
2. sign the app
3. notarize the app
4. staple the app
5. create the `.dmg`
6. create a **GitHub Release**
7. upload the `.dmg` as a release asset

This is the standard public release flow.

## Version Tagging Workflow

Public releases will be created by pushing a git tag.

Example:

```bash
git tag -a v0.1.0 -m "TypingLens v0.1.0"
git push origin v0.1.0
```

A simpler lightweight tag also works:

```bash
git tag v0.1.0
git push origin v0.1.0
```

Recommended versioning format:

- `v0.1.0`
- `v0.1.1`
- `v0.2.0`

## Expected Repository Changes

### Project structure

Add:

- `TypingLens.xcodeproj`
- macOS app target
- `Info.plist`
- app icon asset catalog
- build settings for bundle identifier, versioning, and signing

### Scripts

Likely helper scripts:

- `scripts/build-app.sh`
- `scripts/sign-and-notarize.sh`
- `scripts/create-dmg.sh`

These can encapsulate local and CI release steps.

### GitHub Actions

Add workflow(s) to:

- build on `main`
- sign/notarize/package
- upload artifacts on `main`
- publish Releases on version tags

## GitHub Secrets / Credentials Needed

The CI pipeline will require secrets for signing and notarization.

Likely required:

- Apple Developer account credentials or notarization credentials
- Apple Team ID
- Developer ID Application certificate material
- certificate password
- temporary keychain password

A likely secret set could include:

- `APPLE_DEVELOPER_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `BUILD_CERTIFICATE_BASE64`
- `P12_PASSWORD`
- `KEYCHAIN_PASSWORD`

Prefer modern notarization using **`notarytool`**.

## Recommended Release Architecture

The recommended final architecture is:

- native **Xcode macOS app project**
- bundle id `io.typinglens.app`
- **Apple Silicon** build target
- **Developer ID signing**
- **Apple notarization**
- **DMG packaging**
- **GitHub Actions** automation
- **GitHub Releases** for tagged public versions

## Implementation Order

Recommended implementation sequence:

1. create the Xcode app project
2. wire the existing Swift code into the app target
3. confirm local app bundle builds successfully
4. add signing-friendly app metadata and configuration
5. add notarization and DMG packaging scripts
6. add GitHub Actions workflow
7. document required GitHub secrets and release steps

## Summary

TypingLens should move from a Swift-package-only executable build to a standard macOS app release pipeline built around an Xcode app target. Releases will be distributed as signed and notarized DMGs through GitHub Releases, while pushes to `main` will generate downloadable notarized DMG artifacts via GitHub Actions.