# Auto-Update Feature — Consolidated Audit Report

## Files Changed

- `Sources/ClaudeTmpMonitor/UpdateService.swift`
- `Sources/ClaudeTmpMonitor/ContentView.swift`
- `Sources/ClaudeTmpMonitor/App.swift`
- `Sources/ClaudeTmpMonitor/SettingsView.swift`
- `Sources/ClaudeTmpMonitor/AboutView.swift`
- `Sources/ClaudeTmpMonitor/MonitorService.swift`

---

## 1. QA Audit

1. **[Critical]** Shell injection in `installUpdate()` — paths interpolated into bash script without escaping. Attacker-controlled `.app` name from zip could inject commands.
2. **[High]** `Process.waitUntilExit()` blocks main thread during ditto extraction, freezing UI.
3. **[High]** `DownloadProgressDelegate` created as local variable, may be deallocated before download completes.
4. **[High]** `downloadTask` property never assigned — `cancelDownload()` is a no-op, download continues silently.
5. [FIXED] **[Medium]** Version comparison silently drops non-numeric segments — documented in comment.
6. **[Medium]** No timeout or size limit on download request.
7. **[Medium]** 3-second auto-clear of `.upToDate` has fragile timing (mitigated by `@MainActor` serialization).
8. [FIXED] **[Medium]** `checkForUpdatesAutomatically` `didSet` fires during `init`, causing double `startTimer()`.
9. [FIXED] **[Low]** Updater shell script does not clean itself up.
10. **[Low]** `currentVersion` returns "0.0.0" during development (mitigated by `installUpdate` guard).
11. **[Low]** `.error` state persists in banner until user action (acceptable UX).
12. **[Low]** `checkForUpdates` in AppDelegate opens popover before result is ready (user sees transition).
13. [FIXED] **[Info]** `compareVersions` is `func` (internal) but should be `private`.
14. **[Info]** Settings window height may need visual verification.

## 2. Security Audit

1. [FIXED] **[Critical]** Shell injection via `currentAppPath` and `newAppPath` in `installUpdate()` — paths passed as positional arguments instead of interpolated.
2. **[High]** No integrity verification (code signature) of downloaded update — accepted risk, HTTPS-only.
3. [FIXED] **[High]** `rm -rf` on paths derived from untrusted input — `tempDir` now uses known constant path, not derived from downloaded content.
4. [FIXED] **[Medium]** Download delegate not retained / `downloadTask` not assigned.
5. **[Medium]** TOCTOU between `isWritableFile` check and script execution — accepted (script handles failures).
6. [FIXED] **[Medium]** `waitUntilExit()` blocks main thread — moved to background `DispatchQueue`.
7. [FIXED] **[Medium]** Download URL scheme not validated — added HTTPS check.
8. [FIXED] **[Low]** Version comparison silently drops non-numeric — documented.
9. **[Low]** Timer scheduling depends on main RunLoop (guaranteed by `@MainActor`).
10. **[Low]** `DownloadProgressDelegate` not `Sendable` — closure marked `@Sendable`.
11. [FIXED] **[Info]** Updater script at predictable path — now uses UUID in filename.

## 3. Interface Contract Audit

1. [FIXED] **[Critical]** `downloadTask` never assigned, cancel is no-op — replaced with `Task` cancellation.
2. [FIXED] **[High]** Shell injection — fixed with positional arguments.
3. **[High]** No code signature verification — deferred, HTTPS-only mitigates.
4. [FIXED] **[High]** `waitUntilExit()` blocks main thread — fixed.
5. [FIXED] **[Medium]** `DownloadProgressDelegate` not `@Sendable` — closure marked `@Sendable`.
6. **[Medium]** `shouldShowBanner` and `isActiveUpdate` edge case with dismissed + error — accepted UX behavior.
7. **[Medium]** No timeout on download — deferred (system default timeout applies).
8. [FIXED] **[Medium]** `didSet` fires during init — guarded with `isInitializing` flag.
9. **[Medium]** Version comparison drops non-numeric — documented in doc comment.
10. **[Medium]** Stale status after `Task.sleep` — mitigated by `@MainActor` serialization.
11. **[Low]** `currentVersion` in dev mode — mitigated by install guard.
12. **[Low]** "Retry" button always re-checks rather than retrying failed operation — acceptable simplification.
13. **[Low]** Both services use independent timers — acceptable, no coordination needed.
14. **[Info]** `SettingsView` receives full `UpdateService` for single binding — acceptable overhead.

## 4. State Management Audit

1. [FIXED] **[High]** `didSet` fires during init — guarded with `isInitializing` flag.
2. [FIXED] **[High]** Progress delegate creates burst of `@MainActor` tasks — throttled to 1% increments.
3. [FIXED] **[High]** `downloadTask` never assigned — replaced with `Task` cancellation.
4. **[Medium]** Race between `checkForUpdates` guard and state changes across `await` — mitigated by `@MainActor`.
5. **[Medium]** `shouldShowBanner` depends on non-`@Published` `dismissedVersion` — works because `dismissUpdate()` also sets `status = .idle`.
6. [FIXED] **[Medium]** `didSet` persistence fires during init — now uses explicit persist calls.
7. **[Medium]** `.upToDate` → `.idle` 3-second revert timing — fragile but safe under actor isolation.
8. [FIXED] **[Medium]** Duplicate version reading in `UpdateService` and `AboutView` — `AboutView` now uses `updateService.currentVersion`.
9. **[Low]** Timer depends on main RunLoop — guaranteed by `@MainActor`.
10. **[Low]** No shared settings persistence coordinator — acceptable, `SettingsKey` prevents collisions.
11. **[Low]** No cross-service communication — not needed currently.
12. [FIXED] **[Info]** `compareVersions` has broader visibility than needed — made `private`.

## 5. Resource & Concurrency Audit

1. [FIXED] **[High]** `downloadTask` never assigned — replaced with `Task` cancellation.
2. [FIXED] **[High]** `DownloadProgressDelegate` deallocated mid-download — stored as instance property.
3. [FIXED] **[High]** `waitUntilExit()` blocks main thread — moved to background `DispatchQueue` with `withCheckedThrowingContinuation`.
4. [FIXED] **[Medium]** Shell script path injection — uses positional arguments.
5. **[Medium]** Zombie process from updater — reparented by OS on terminate, acceptable.
6. [FIXED] **[Medium]** No timeout on ditto process — extraction is now async, can be cancelled via Task cancellation.
7. [FIXED] **[Medium]** Temp directory not cleaned on all error paths — added cleanup on all error/early-return paths.
8. **[Medium]** `deinit` on `@MainActor` may not run on main thread — timer invalidation is best-effort on terminate.
9. **[Low]** Race between `Task.sleep` and status — safe under actor isolation.
10. **[Low]** Timer requires active RunLoop — guaranteed by `@MainActor`.
11. [FIXED] **[Low]** No bounds on progress callback frequency — throttled to 1% increments.

## 6. Testing Coverage Audit

1. **[Critical]** No test target exists — entire UpdateService untested. `compareVersions` is trivially unit-testable.
2. **[Critical]** `installUpdate()` is untestable as written — no seams for dependency injection.
3. **[High]** No protocol abstractions for URLSession/FileManager/Bundle — prevents dependency injection.
4. **[High]** `compareVersions` drops non-numeric segments — needs test cases.
5. [FIXED] **[High]** `DownloadProgressDelegate` may be deallocated — stored as instance property.
6. [FIXED] **[High]** `downloadTask` never assigned — replaced with `Task`.
7. **[Medium]** No tests for `shouldShowBanner` state transitions.
8. **[Medium]** No tests for auto-check-on-launch timing logic.
9. **[Medium]** `isActiveUpdate` does not include `.available` — documented behavior.
10. **[Medium]** 3-second `Task.sleep` creates non-deterministic timing for tests.
11. **[Medium]** No fixture-based tests for GitHub API JSON parsing.
12. **[Low]** `UpdateStatus` Equatable with `Double` — floating-point comparison fragility.
13. **[Low]** No test for `cancelDownload()` temp cleanup.
14. **[Info]** `DownloadProgressDelegate` is `private` — cannot be tested without `@testable`.
15. **[Info]** `compareVersions` was the only testable method — now `private`, would need `@testable import`.

## 7. DX & Maintainability Audit

1. [FIXED] **[High]** `checkForUpdates` exceeds 50 lines — extracted `fetchLatestRelease()`.
2. [FIXED] **[High]** `downloadUpdate` mixes concerns — extracted `performDownload()` and `extractAndFindApp()`.
3. [FIXED] **[High]** `downloadTask` never assigned — fixed.
4. [FIXED] **[Medium]** `compareVersions` should be `private` — made `private` with doc comment.
5. [FIXED] **[Medium]** Duplicate version retrieval — `AboutView` uses `updateService.currentVersion`.
6. **[Medium]** `updateBannerSection` is ~100 lines — acceptable for a single switch statement, each case is self-contained.
7. **[Medium]** Magic number `30` in install script — acceptable, the "30 seconds" is clear from `seq 1 30` + `sleep 1`.
8. [FIXED] **[Medium]** Magic number `15` for API timeout — extracted to `apiTimeoutSeconds` constant.
9. [FIXED] **[Medium]** Shell script path injection — fixed with positional arguments.
10. [FIXED] **[Low]** `DownloadProgressDelegate` may be deallocated — stored as instance property.
11. **[Low]** No doc comments on `UpdateStatus`/`UpdateService` — acceptable for internal types in small codebase.
12. **[Low]** `isActiveUpdate` naming could be clearer — acceptable, usage is clear in context.
13. **[Low]** `updateCheckInterval` is `let` — noted for future configurability.
14. [FIXED] **[Low]** `3_000_000_000` sleep without comment — added comment.
15. **[Info]** No keyboard shortcut for "Check for Updates" — standard practice.
16. **[Info]** Settings window height — needs visual verification.

---

## Unresolved Items (Accepted)

- **No code signature verification** — Acceptable for non-code-signed app distributed via HTTPS GitHub releases. Could add `codesign --verify` in a future release.
- **No test target** — Project has no tests at all; adding a test target is a separate initiative.
- **TOCTOU on install** — Script may race with filesystem changes between check and execution. Acceptable risk for a self-update mechanism.
- **`.upToDate` 3-second auto-clear timing** — Fragile but safe under `@MainActor` serialization.
- **No download timeout** — System default timeout applies. Could add explicit timeout in future.
- **`deinit` timer invalidation** — Best-effort on app termination, no practical impact.
