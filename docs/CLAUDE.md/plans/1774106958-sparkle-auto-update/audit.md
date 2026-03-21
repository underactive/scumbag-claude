# Audit: Migrate Auto-Update to Sparkle 2.x

## Files changed
- `Sources/ClaudeTmpMonitor/App.swift`
- `Sources/ClaudeTmpMonitor/ContentView.swift`
- `Sources/ClaudeTmpMonitor/AboutView.swift`
- `Sources/ClaudeTmpMonitor/SettingsView.swift`
- `Sources/ClaudeTmpMonitor/MonitorService.swift`
- `Package.swift`
- `Info.plist`
- `Makefile`
- `.github/workflows/release.yml`

## QA Audit

1. **[Critical]** `SUPublicEDKey` in Info.plist is a placeholder string. Sparkle will reject all update signatures until the real public key is embedded. (Intentional — documented as a manual prerequisite in the plan. Must be replaced before first Sparkle-powered release.)
2. **[High]** `sign_update` piping approach (`echo $KEY | sign_update`) may not work — Sparkle's `sign_update` reads the key from the `SPARKLE_PRIVATE_KEY` env var directly, not stdin. If the grep pattern fails to match, `$SIGNATURE` will be empty and the appcast will have an invalid signature.
3. **[Medium]** Appcast XML heredoc in release.yml produces leading whitespace before the `<?xml?>` declaration, which violates XML spec section 2.8.
4. **[Medium]** Sparkle.framework discovery via `find | head -1` is non-deterministic — could pick wrong copy if multiple exist.
5. **[Low]** Manual `Binding(get:set:)` on `SPUUpdater.automaticallyChecksForUpdates` won't re-render on external changes. Low practical impact since nothing else mutates this while Settings is open.
6. **[Info]** Sparkle handles network failures and missing appcast gracefully. No special handling needed.

## Security Audit

7. **[High]** Sparkle tools downloaded in CI from `/releases/latest` with no version pin or checksum verification. Combined with piping the EdDSA private key to the downloaded binary, a supply-chain compromise would grant the attacker the signing key.
8. [FIXED] **[Medium]** Missing `--preserve-metadata=entitlements` on Sparkle XPC service signing — could strip entitlements needed for Downloader and Installer.
9. **[Medium]** Appcast XML built via shell string interpolation without validation. If `$SIGNATURE` is empty, a broken appcast entry is silently published.
10. **[Low]** Appcast served from gh-pages without branch protection. EdDSA signature protects the DMG itself.
11. [FIXED] **[Low]** Fragile regex for signature extraction with no empty check.

## Interface Contract Audit

12. **[N/A]** No remaining UpdateService references. Clean removal.
13. **[N/A]** SPUUpdater properly threaded from AppDelegate to SettingsView.
14. **[Medium]** Manual Binding on `automaticallyChecksForUpdates` won't reactively update if Sparkle changes the value externally while Settings is open. `SPUUpdater.automaticallyChecksForUpdates` is KVO-compliant, so a KVO-backed wrapper could be added. Accepted as-is — low practical impact.
15. **[N/A]** All environmentObject chains correct.

## State Management Audit

16. **[N/A]** `SPUStandardUpdaterController` properly retained by AppDelegate for app lifetime.
17. **[N/A]** No race condition — both Sparkle and SwiftUI binding are @MainActor-confined.
18. **[Info]** Old UserDefaults keys orphaned but harmless. No dual source of truth.

## Resource & Concurrency Audit

19. **[Medium]** `install_name_tool` errors silently suppressed with `2>/dev/null || true`.
20. [FIXED] **[Medium]** Sparkle tools not version-pinned, no checksum, no error handling on download.
21. **[Low]** Appcast push failure leaves stale state — release DMG uploads but appcast is not updated.
22. [FIXED] **[Low]** `awk` appcast insertion has no error handling. `set -e` should be added.

## Testing Coverage Audit

23. **[Medium]** Missing: First-launch behavior with Sparkle (consent dialog, behavior when appcast doesn't exist).
24. **[Medium]** Missing: Migration from old updater — user who disabled auto-check gets Sparkle's default (enabled).
25. **[Medium]** Missing: EdDSA signature validation failure path (placeholder key scenario).
26. **[Low]** Missing: Framework loading failure / dev build behavior with `swift run`.
27. **[Low]** Missing: Release pipeline verification (valid appcast entry after GitHub release).

## DX & Maintainability Audit

28. [FIXED] **[Medium]** Appcast XML heredoc produces leading whitespace before XML declaration.
29. **[Low]** Long shell script in single workflow step — could split for debuggability.
30. **[Low]** `.PHONY` missing `install` target. (Pre-existing, not introduced by this change.)
31. **[Info]** No dead code from UpdateService found. Clean removal confirmed.
