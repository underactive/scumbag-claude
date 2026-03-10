# Plan: Code Signing & Notarization in CI

## Objective

Add Developer ID code signing and Apple notarization to the GitHub Actions release workflow so that downloaded `.app` bundles open without Gatekeeper quarantine warnings. This also ensures the auto-update flow works seamlessly since `xattr -cr` cannot reliably clear quarantine on unsigned apps.

## Changes

### 1. `.github/workflows/release.yml`
- Add steps to import a Developer ID certificate from GitHub Secrets into a temporary keychain
- Sign the `.app` bundle with `codesign --force --deep --options runtime`
- Create a zip, submit to `notarytool` for notarization, wait for completion
- Staple the notarization ticket to the `.app` bundle
- Re-zip the stapled app for the release asset
- Clean up the temporary keychain

### 2. `CLAUDE.md`
- Update Architecture > Auto-Update section to note that releases are signed and notarized
- Remove Known Issues #5 (Gatekeeper quarantine on auto-update) since it will be resolved
- Add required GitHub Secrets to Build Configuration section

## Dependencies

Before this workflow works, the following GitHub repository secrets must be configured:
- `DEVELOPER_ID_P12` — base64-encoded `.p12` export of the "Developer ID Application" certificate + private key
- `P12_PASSWORD` — password used when exporting the `.p12`
- `APPLE_ID` — Apple ID email used for notarization
- `APP_SPECIFIC_PASSWORD` — app-specific password generated at appleid.apple.com (not the Apple ID password)
- `TEAM_ID` — 10-character Apple Developer Team ID

## Risks / open questions

1. **Notarization latency** — `notarytool --wait` can take 1-15 minutes. The workflow will block during this time.
2. **Hardened runtime** — `--options runtime` enables hardened runtime, which is required for notarization. If the app uses any restricted entitlements (JIT, unsigned memory, etc.), an entitlements plist would need to be passed. Current app uses no restricted entitlements.
3. **`codesign --deep` vs explicit signing** — `--deep` signs all nested bundles. For a simple app this is fine; complex apps with frameworks should sign inside-out explicitly.
