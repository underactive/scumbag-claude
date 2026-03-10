# Auto-Update Feature — Implementation

## Files Changed

- `Sources/ClaudeTmpMonitor/MonitorService.swift` — Added 3 `SettingsKey` constants: `checkForUpdatesAutomatically`, `lastUpdateCheckTime`, `dismissedUpdateVersion`
- `Sources/ClaudeTmpMonitor/UpdateService.swift` — **NEW** — Full `@MainActor class UpdateService: ObservableObject` with `UpdateStatus` enum, GitHub API checking, zip download with progress delegate, ditto-based extraction, shell-script self-replacement, semantic version comparison, periodic timer, UserDefaults persistence
- `Sources/ClaudeTmpMonitor/App.swift` — Added `updateService` property to `AppDelegate`, injected as `.environmentObject()` on ContentView/SettingsView/AboutView, added "Check for Updates..." right-click menu item with `@objc checkForUpdates()` handler that opens popover
- `Sources/ClaudeTmpMonitor/ContentView.swift` — Added `@EnvironmentObject var updateService`, added `updateBannerSection` between projects/empty and footer with states for available/downloading/readyToInstall/installing/error
- `Sources/ClaudeTmpMonitor/SettingsView.swift` — Added `@EnvironmentObject var updateService`, added "Check for updates automatically" toggle after "Launch at Login"
- `Sources/ClaudeTmpMonitor/AboutView.swift` — Added `@EnvironmentObject var updateService`, added `updateStatusText` computed property showing available/upToDate/checking status below version string
- `CLAUDE.md` — Updated Core Files count (5→6), added UpdateService description, updated App.swift description, updated ContentView description, added URLSession dependency, added Auto-Update subsystem section, updated Data Flow, added update settings to Settings section, added Known Issues 5-7, added "Change GitHub repo URL" common modification, updated File Inventory

## Summary

Implemented exactly as planned. The `UpdateService` handles the full lifecycle: periodic checking (24h default), GitHub releases API parsing, zip download with `URLSessionDownloadDelegate` for progress tracking, `ditto -xk` extraction, and shell-script-based self-replacement with `xattr -cr` quarantine clearing. The UI surfaces state through a banner in the popover, a right-click menu item, an About dialog status line, and a Settings toggle.

No deviations from the plan.

## Verification

- `swift build` — successful compilation with no errors or warnings
- All 6 source files compile together correctly
- Environment object wiring verified: AppDelegate → ContentView, SettingsView, AboutView

## Follow-ups

- End-to-end testing requires a newer version tag on GitHub (or temporarily modifying version comparison)
- Consider adding SHA256 checksum verification in a future release
- Consider adding delta/incremental updates to reduce download size
- Consider adding code signature verification (`codesign --verify`) on downloaded `.app`
- Consider adding a test target with unit tests for `compareVersions` and GitHub API JSON parsing

## Audit Fixes

### Fixes Applied

1. **Shell injection in `installUpdate()`** (Security §1, QA §1) — Paths are now passed as positional arguments (`$1`, `$2`, `$3`) to the bash script instead of being interpolated into the script body. `tempDir` uses a known constant path instead of being derived from downloaded content.
2. **`downloadTask` never assigned / cancel is a no-op** (QA §4, Security §4, Resource §1, State §3) — Replaced `URLSessionDownloadTask?` with `Task<Void, Never>?`. `downloadUpdate()` now stores the download `Task`, and `cancelDownload()` cancels it. The async download respects `CancellationError`.
3. **`DownloadProgressDelegate` premature deallocation** (QA §3, Resource §2) — Delegate is now stored as `progressDelegate` instance property on `UpdateService`, keeping it alive for the duration of the download. Cleared after download completes or on cancel.
4. **`Process.waitUntilExit()` blocks main thread** (QA §2, Security §6, Resource §3) — Ditto extraction is now run on a background `DispatchQueue` via `withCheckedThrowingContinuation`, returning to `@MainActor` asynchronously.
5. **`didSet` fires during init** (QA §9, State §1, Interface §8) — Added `isInitializing` flag, `didSet` on `checkForUpdatesAutomatically` returns early when flag is set. `dismissedVersion` and `lastCheckTime` no longer use `didSet` for persistence; explicit `persistCheckTime()` and inline `UserDefaults.set` calls in `dismissUpdate()` instead.
6. **Temp directory not cleaned on all error paths** (Resource §7) — All error paths and early returns in `performDownload()` now call `fm.removeItem(at: tempDir)`.
7. **No HTTPS scheme validation on download URL** (Security §7) — `downloadUpdate()` validates `downloadURL.scheme == "https"` before proceeding.
8. **Updater script doesn't clean itself up** (QA §10) — Script now includes `rm -f "$0"` to remove itself after execution.
9. **Updater script at predictable path** (Security §11) — Script filename now includes a UUID for uniqueness.
10. **`compareVersions` not private** (QA §14, DX §4, State §12) — Made `private` with a `///` doc comment noting non-numeric segment behavior.
11. **Duplicate version string** (DX §5, State §8) — `AboutView` now uses `updateService.currentVersion` instead of reading `Bundle.main` independently.
12. **Magic number for API timeout** (DX §8) — Extracted to `apiTimeoutSeconds` constant.
13. **Methods exceed 50 lines** (DX §1, §2) — `checkForUpdates` extracted `fetchLatestRelease()`. `downloadUpdate` extracted `performDownload()` and `extractAndFindApp()`. Errors extracted to `UpdateError` enum.
14. **Progress delegate callback flooding** (State §2, Resource §11) — Throttled to report only when progress changes by at least 1%. Closure marked `@Sendable`.
15. **`tempDir` derived from downloaded content** (Security §3) — Install script uses the known `scumbag-claude-update` temp directory constant, not a path derived from the downloaded archive.

### Verification Checklist

- [x] `swift build` compiles successfully
- [ ] Verify shell script uses `$1`, `$2`, `$3` arguments (no interpolated paths)
- [ ] Verify "Cancel" button during download actually stops the download task
- [ ] Verify ditto extraction does not freeze the UI
- [ ] Verify `didSet` does not fire during `UpdateService.init()` (no double timer start)
- [ ] Verify temp directory is cleaned up after failed downloads
- [ ] Verify non-HTTPS download URLs are rejected
- [ ] Verify updater script removes itself after execution
- [ ] Verify progress bar updates smoothly without excessive redraws
