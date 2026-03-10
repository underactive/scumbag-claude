# Implementation: Code Signing & Notarization in CI

## Files changed
- `.github/workflows/release.yml` — modified: added certificate import, codesign, notarization, stapling, and keychain cleanup steps
- `CLAUDE.md` — modified: added signing/notarization note to Auto-Update section, removed Gatekeeper known issue, added GitHub Actions Secrets section
- `docs/CLAUDE.md/plans/1773172148-codesign-notarize/plan.md` — created
- `docs/CLAUDE.md/plans/1773172148-codesign-notarize/implementation.md` — created

## Summary

Updated the release workflow to:
1. Import a Developer ID certificate from GitHub Secrets into a temporary keychain
2. Sign the `.app` bundle with `codesign --force --deep --options runtime`
3. Verify the signature with `codesign --verify --deep --strict`
4. Submit to Apple's notary service via `notarytool --wait`
5. Staple the notarization ticket to the `.app` bundle
6. Zip the signed+stapled app for the release asset
7. Clean up the temporary keychain (runs even on failure via `if: always()`)

Added `SIGNING_IDENTITY` as a separate secret (not derived from other secrets) to avoid hardcoding the identity string in the workflow.

## Verification

- Workflow syntax is valid YAML
- No secrets are logged or exposed in step outputs
- Certificate cleanup runs unconditionally via `if: always()`
- Cannot fully verify until GitHub Secrets are configured and a tagged release is pushed

## Follow-ups

- Workflow cannot run until all 6 GitHub Secrets are configured in the repository settings
- First tagged release after secrets are configured should be tested by downloading the zip and verifying it opens without Gatekeeper warnings
- Consider adding a `--timeout` to `notarytool submit --wait` to prevent indefinite hangs (default is 5 minutes, usually sufficient)
