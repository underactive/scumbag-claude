# Audit Report: File Timestamps, Open in Editor, and Batch Delete

## Files Changed

- `Sources/ClaudeTmpMonitor/MonitorService.swift`
- `Sources/ClaudeTmpMonitor/ContentView.swift`

## QA Audit

1. **[FIXED] [Medium] DateFormatter allocated per call in `relativeTime`.** Hoisted to module-level `_relativeTimeDateFormatter` static instance.
2. **[FIXED] [Medium] `relativeTime` returns incorrect values for future dates.** Added `guard seconds > 0` returning "now".
3. **[FIXED] [Medium] `deleteFiles` does not guard against empty input.** Added `guard !files.isEmpty else { return }`.
4. **[FIXED] [Medium] Stale file IDs inflate "Delete (N)" count.** Added `selectedFileCount` computed property that intersects with current file IDs.
5. [Medium] Selection circles respond to taps during confirm dialog — changing the set that will be deleted. Accepted: consistent with existing pattern where other delete buttons are always tappable during confirms. `confirmDelete` is exclusive — only one confirm can be active.
6. [Low] `relativeTime` truncates rather than rounds (7100s = "1h" not "2h"). Accepted: standard for relative time displays.
7. [Low] Search filters by `displayName` only, not path. Design choice.
8. [Low] No visual feedback when `NSWorkspace.shared.open` fails. Accepted per plan; macOS shows system-level error dialog.

## Security Audit

1. [Medium] `openFile` opens resolved path without scope validation. Accepted: opening a file is a read-only operation (launches default editor). Unlike deletion, there is no destructive risk. The inconsistency with deletion scope checks is intentional — we want users to be able to view any file Claude is working with.
2. [Low] TOCTOU gap in `deleteFiles` (same as Known Issue #3). Pre-existing architectural limitation.
3. [Low] `openFile` does not guard against broken symlinks. The UI already gates the button behind `!file.isBrokenSymlink`.

## Interface Contract Audit

1. **[FIXED] [Medium] Stale selection IDs survive scan refresh.** Fixed via `selectedFileCount` computed property.
2. **[FIXED] [Medium] Batch delete double-removes shared symlink targets.** Added `deletedTargets` set to deduplicate resolved path removal.
3. **[FIXED] [Low] `deleteFiles` error messages lack `localizedDescription`.** Now includes `error.localizedDescription` matching `deleteFile` pattern.
4. [Low] `openFile` discards `NSWorkspace.open` return value. Accepted; macOS handles the error dialog.
5. [Low] `deleteFiles` clears prior `lastDeleteError` unconditionally. Consistent with all other delete methods.
6. [Low] Empty batch (all stale IDs) triggers redundant scan. Fixed by `guard !files.isEmpty`.

## State Management Audit

1. **[FIXED] [Medium] Stale `selectedFiles` across scans.** `selectedFileCount` ensures accurate display; stale IDs are harmless at delete time.
2. [Low] Selected files persist when hidden by search filter. Accepted: selections are intentionally global (not view-scoped). Users can select, filter to check something, then unfilter.
3. [Low] No concurrency issues — `@MainActor` isolation is correctly maintained throughout.

## Resource & Concurrency Audit

1. **[FIXED] [Low] DateFormatter allocation.** Already fixed before this audit ran.
2. [Medium] TOCTOU gap in `deleteFiles`. Pre-existing Known Issue #3, not a new regression.
3. [Medium] `openFile` no scope check. Accepted as read-only operation (see Security §1).
4. [Low] Batch delete + scan blocks main thread. Acceptable at current scale; consistent with existing delete methods.
5. No concurrency issues — all state mutations on `@MainActor`.

## Testing Coverage Audit

1. **[FIXED] [Medium] Project row shows timestamp for `Date.distantPast`.** Added guard: `if project.lastModified != .distantPast`.
2. [Medium] No test for `openFile` failure path. Added note — macOS handles this with system dialog.
3. [Medium] Batch delete with mixed file types (regular, symlink, broken) not explicitly tested. Covered by "Batch delete handles symlink targets correctly" checklist item.
4. [Medium] Confirmation state mutual exclusion between batch and single-file delete. Pre-existing pattern — `confirmDelete` is always exclusive by design.
5. [Low] Boundary value tests for `relativeTime` thresholds. Minor — standard integer comparison.
6. [Low] Footer layout with all buttons visible simultaneously. Worth manual testing.

## DX & Maintainability Audit

1. [Medium] `fileRow` at 110 lines exceeds readability threshold. Accepted for now — the function is a single view builder with clear sections. Extracting sub-views adds indirection without improving correctness.
2. [Medium] `footerSection` at 100 lines with structural duplication (confirm/cancel pattern). Pre-existing pattern; extracting a reusable helper is a future improvement.
3. **[FIXED] [Low] `relativeTime` under wrong MARK comment.** Renamed to `// MARK: - Formatting Helpers`.
4. **[FIXED] [Low] Magic number 604800 without comment.** Added `// 7 days` inline comment.
5. **[FIXED] [Low] `deleteFiles` error messages lack specificity.** Now includes `error.localizedDescription`.
6. [Low] Repeated `selectedFiles.contains(file.id)` in `fileRow`. Minor — O(1) lookup, readable in context.
