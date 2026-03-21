# Implementation: File Timestamps, Open in Editor, and Batch Delete

## Files Changed

- `Sources/ClaudeTmpMonitor/MonitorService.swift` — added `relativeTime()` top-level function and `deleteFiles(_:)` batch delete method
- `Sources/ClaudeTmpMonitor/ContentView.swift` — added timestamps to file/project rows, open button on file rows, selection circles with batch delete, `selectedFiles` state, `DeleteConfirmation.selectedFiles` case, footer "Delete (N)" button, helper functions `toggleFileSelection`, `openFile`
- `CLAUDE.md` — updated ContentView description
- `docs/CLAUDE.md/future-improvements.md` — checked off 3 items
- `docs/CLAUDE.md/testing-checklist.md` — added 22 test items across 3 sections
- `docs/CLAUDE.md/version-history.md` — updated v0.4.4 entry

## Summary

Implemented all three features as planned:

1. **Timestamps**: `relativeTime()` returns compact strings ("now", "2m", "3h", "2d", "Mar 15"). Shown next to file size in file rows and appended to project subtitle. Broken symlinks excluded (Date.distantPast).

2. **Open file**: `arrow.up.forward.app` icon button on non-broken file rows. Uses `NSWorkspace.shared.open(URL(fileURLWithPath: file.resolvedPath))` to open the resolved target in the default application. Hidden for broken symlinks.

3. **Batch delete**: Selection circles (empty circle / checkmark.circle.fill) on every file row. `selectedFiles: Set<String>` tracks IDs globally. "Delete (N)" button in footer with confirm/cancel flow. `MonitorService.deleteFiles(_:)` handles batch deletion with single scan. Selection cleared on: popover open, batch delete, Clean All, project delete (for that project's files).

**Minor deviation from plan**: File section left padding reduced from 24px to 16px to compensate for the selection circle width, keeping file names roughly aligned with project names.

## Verification

1. `swift build -c release` — clean build, no warnings or errors
2. Manual testing checklist items documented in `testing-checklist.md`

## Follow-ups

- `fileRow` at 110 lines and `footerSection` at 100 lines exceed readability threshold. Consider extracting sub-views if these grow further.
- Confirm/cancel pattern is repeated 4 times in the footer. Could extract a reusable helper.

## Audit Fixes

### Fixes applied

1. **DateFormatter allocation** (QA §1, Resource §1) — hoisted to module-level `_relativeTimeDateFormatter` static instance.
2. **Future date guard** (QA §2) — `guard seconds > 0 else { return "now" }` in `relativeTime`.
3. **Empty input guard** (QA §3, Interface §6) — `guard !files.isEmpty else { return }` in `deleteFiles`.
4. **Stale selection count** (QA §4, State §1, Interface §1) — added `selectedFileCount` computed property that intersects `selectedFiles` with current file IDs. Footer uses this for accurate display.
5. **Symlink target deduplication** (Interface §2) — `deletedTargets` set in `deleteFiles` prevents double-removal of shared resolved paths.
6. **Project timestamp for distantPast** (Testing §1) — project subtitle guards `project.lastModified != .distantPast` before showing timestamp.
7. **MARK comment** (DX §3) — renamed `// MARK: - Byte Formatting` to `// MARK: - Formatting Helpers`.
8. **Magic number comment** (DX §4) — added `// 7 days` after `604800` threshold.
9. **Error message specificity** (DX §5) — `deleteFiles` now includes `error.localizedDescription` in error messages, matching `deleteFile` pattern.

### Verification checklist

- [ ] Verify "Delete (N)" count is accurate after a scan deletes a selected file externally
- [ ] Verify batch deleting files that share a symlink target does not produce spurious error messages
- [ ] Verify project subtitle does not show a timestamp when all files are broken symlinks
- [ ] Verify `relativeTime` returns "now" for future-dated files (clock skew)
- [ ] `swift build -c release` passes after fixes (confirmed)

### Unresolved items

- [Medium] `fileRow` at 110 lines — accepted; clear section structure, not decomposable without adding indirection
- [Medium] `footerSection` at 100 lines — pre-existing structural pattern
- [Medium] Selection circles tappable during confirm dialog — consistent with existing UI pattern
- [Medium] `openFile` has no scope validation — intentional; opening is read-only, not destructive
- [Low] TOCTOU gap in `deleteFiles` — pre-existing Known Issue #3
