# Implementation: Migrate Auto-Update to Sparkle 2.x

## Files changed

- `Package.swift` — Added Sparkle 2.6+ as SPM binary dependency, linked to ClaudeTmpMonitor target
- `Info.plist` — Added `SUFeedURL` (appcast URL) and `SUPublicEDKey` (placeholder for EdDSA public key)
- `Sources/ClaudeTmpMonitor/UpdateService.swift` — **DELETED** — 445 lines of custom update logic replaced by Sparkle
- `Sources/ClaudeTmpMonitor/App.swift` — Replaced `UpdateService` with `SPUStandardUpdaterController(startingUpdater: true)`, removed `updateService` environment object injection from ContentView/SettingsView/AboutView, rewired `checkForUpdates()` to call Sparkle, passed `SPUUpdater` to SettingsView as init parameter
- `Sources/ClaudeTmpMonitor/ContentView.swift` — Removed `@EnvironmentObject var updateService`, removed update banner conditional block and entire `updateBannerSection` computed property (~98 lines)
- `Sources/ClaudeTmpMonitor/AboutView.swift` — Removed `@EnvironmentObject var updateService`, replaced `updateService.currentVersion` with `Bundle.main.infoDictionary` lookup, removed `updateStatusText` ViewBuilder
- `Sources/ClaudeTmpMonitor/SettingsView.swift` — Added `import Sparkle`, added `let updater: SPUUpdater` init parameter, removed `@EnvironmentObject var updateService`, rewired auto-check toggle to use `Binding(get:set:)` on `updater.automaticallyChecksForUpdates`
- `Sources/ClaudeTmpMonitor/MonitorService.swift` — Removed 3 orphaned `SettingsKey` constants (`checkForUpdatesAutomatically`, `lastUpdateCheckTime`, `dismissedUpdateVersion`)
- `Makefile` — Added `Contents/Frameworks/` directory creation, Sparkle.framework copy from SPM artifacts via `find`, `install_name_tool -add_rpath`, inside-out framework signing in `sign` target
- `.github/workflows/release.yml` — Added `fetch-depth: 0` to checkout, added "Sign embedded frameworks" step (inside-out: XPC services, Updater.app, Autoupdate, framework), added "Download Sparkle tools" step, added "Sign DMG with EdDSA and update appcast" step (signature generation, gh-pages branch management, appcast.xml creation/update)
- `CLAUDE.md` — Updated Core Files (8-file count, App.swift description, removed UpdateService entry, updated ContentView/SettingsView/AboutView descriptions), Dependencies (added Sparkle), Auto-Update subsystem (rewritten for Sparkle), Settings (removed 3 UpdateService settings), Data Flow (removed UpdateService references), Build Configuration (SPM and Makefile descriptions, added SPARKLE_PRIVATE_KEY secret), External Integrations (added Sparkle), Known Issues (removed #4/#5/#6, added Sparkle framework size note, renumbered), Common Modifications (updated GitHub URL section), File Inventory (removed UpdateService row, updated ContentView description)

## Summary

Implemented exactly as planned. The custom `UpdateService` (state machine, GitHub API polling, DMG download/mount/extract, shell script self-replacement, version comparison, download progress delegate) was fully replaced by Sparkle 2.x's `SPUStandardUpdaterController`. The integration is minimal — ~5 lines in App.swift create the controller, the right-click menu delegates to Sparkle's standard update window, and SettingsView binds directly to `SPUUpdater.automaticallyChecksForUpdates`. All custom update UI (popover banner, About dialog status, progress tracking) was removed since Sparkle provides its own native macOS update UI.

The release workflow was updated to: download Sparkle CLI tools, sign the embedded framework inside-out before the outer app bundle, generate EdDSA signatures for the DMG, and maintain an appcast.xml on the gh-pages branch.

## Verification

1. `swift build -c release` — compiles successfully with Sparkle dependency
2. `make bundle` — creates app bundle with Sparkle.framework in Contents/Frameworks/
3. `make sign` — inside-out framework signing succeeds, `codesign --verify --deep --strict` passes
4. All code changes compile without errors

## Follow-ups

- **EdDSA keypair generation** — Must run Sparkle's `generate_keys` tool before first release. Store private key as `SPARKLE_PRIVATE_KEY` GitHub Secret, replace `SUPublicEDKey` placeholder in Info.plist with actual public key.
- **GitHub Pages setup** — Enable GitHub Pages on the repo, pointed at the `gh-pages` branch, before first Sparkle-powered release.
- **First release testing** — The first release with Sparkle should be manually tested end-to-end: verify appcast is published, Sparkle checks it, signature validates, update installs correctly.
- **Legacy UserDefaults cleanup** — Old keys (`checkForUpdatesAutomatically`, `lastUpdateCheckTime`, `dismissedUpdateVersion`) remain in UserDefaults harmlessly. No migration needed.

## Audit Fixes

### Fixes applied

1. Fixed `sign_update` invocation — removed stdin pipe (`echo $KEY |`), now relies on `SPARKLE_PRIVATE_KEY` env var read by the tool directly. Addresses Security Audit H2 and QA Audit §2.
2. Added empty signature guard — if `$SIGNATURE` is empty after extraction, the workflow now fails with a clear error message. Addresses Security Audit §11 and Resource Audit §22.
3. Fixed appcast XML heredoc whitespace — replaced indented heredoc with a properly formatted one (no leading whitespace before `<?xml?>` declaration). Uses `<<'APPCAST_EOF'` to prevent variable expansion in the template. Addresses DX Audit §28 and QA Audit §3.
4. Added `set -e` to both the "Download Sparkle tools" and "Sign DMG with EdDSA" steps to catch errors early. Addresses Resource Audit §22.
5. Pinned Sparkle tools download to version 2.9.0 instead of using `/releases/latest`. Addresses Security Audit §7 and Resource Audit §20.
6. Added `--preserve-metadata=entitlements` to XPC service and helper signing in both Makefile and release.yml. Sparkle's XPC services ship with entitlements (e.g., `com.apple.security.network.client` for Downloader) that are needed at runtime. Addresses Security Audit §8.

### Verification checklist

- [ ] Verify `make sign` still passes `codesign --verify --deep --strict` after entitlements preservation change
- [ ] Verify `sign_update` reads `SPARKLE_PRIVATE_KEY` from env var correctly (test in CI with first release)
- [ ] Verify empty signature guard fires if `SPARKLE_PRIVATE_KEY` secret is not configured
- [ ] Verify appcast.xml has no leading whitespace before `<?xml?>` declaration after first release

### Unresolved items

- **SUPublicEDKey placeholder** (Audit C1) — Intentionally deferred. Requires running `generate_keys` which is a manual prerequisite documented in Follow-ups.
- **Sparkle.framework find path** (Audit §4, §19) — Accepted as-is. The `-path "*/release/Sparkle.framework"` filter already constrains to release builds. The `|| true` on `install_name_tool` handles idempotent re-runs.
- **Manual Binding staleness** (Audit §5, §14) — Accepted as-is. Low practical impact since nothing mutates `automaticallyChecksForUpdates` while Settings is open.
- **Testing checklist gaps** (Audit §23-27) — First-launch behavior, migration from old updater, and signature failure paths should be added to the checklist before the first Sparkle-powered release.
