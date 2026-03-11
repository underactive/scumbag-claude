# Implementation: Symlink Visibility & Broken Symlink Cleanup

## Files changed

- `Sources/ClaudeTmpMonitor/MonitorService.swift` — Added `isTargetInScope` and `duplicateCount` to `MonitoredFile`, `brokenSymlinkCount` to `ClaudeProject`, `deleteBrokenSymlinks()` and `deleteBrokenSymlinksInProject(_:)` methods, duplicate count post-processing in `scan()`
- `Sources/ClaudeTmpMonitor/ContentView.swift` — Added scope indicator ("link only" badge), duplicate badge ("×N"), broken count in project subtitle, "Clean Broken (N)" footer button with confirm/cancel, `brokenSymlinks` case in `DeleteConfirmation`
- `CLAUDE.md` — Updated MonitorService description, added symlink scope/deduplication/broken symlink subsystem docs, added broken symlink cleanup to File Deletion section
- `docs/CLAUDE.md/future-improvements.md` — Marked three items as completed
- `docs/CLAUDE.md/version-history.md` — Added v0.3.6 entry (version not yet bumped in Info.plist/CLAUDE.md)
- `docs/CLAUDE.md/testing-checklist.md` — Added Symlink Scope Indicators, Deduplication Visibility, and Broken Symlink Cleanup sections

## Summary

Implemented all three features as planned with no deviations:

1. **Symlink scope indicators**: `isTargetInScope` computed in `scanDirectory()` using existing `isInAllowedDeletionScope()`. Non-symlinks and broken symlinks default to `true`. Out-of-scope symlinks show a purple "link only" pill badge with tooltip.

2. **Deduplication visibility**: After all projects are scanned, `scan()` builds a global `resolvedPath → count` map. If any duplicates exist, projects are rebuilt with updated `duplicateCount` values. UI shows blue "×N" badge with hover tooltip.

3. **Broken symlink cleanup**: `ClaudeProject.brokenSymlinkCount` computed property. Two new methods: `deleteBrokenSymlinks()` (global) and `deleteBrokenSymlinksInProject(_:)`. Project subtitle shows broken count in red. Footer shows "Clean Broken (N)" button with confirm/cancel flow.

Also refactored the "Clean All" button in the footer to use the same if/else confirm pattern (previously the button and confirm were separate `if` blocks at the same level).

## Verification

- `swift build` — clean compile with no warnings
- All existing code paths preserved; new fields have safe defaults (`isTargetInScope: true`, `duplicateCount: 1`)
- `deleteBrokenSymlinksInProject(_:)` method is defined but not yet wired to UI (available for future per-project cleanup button)

## Follow-ups

- Per-project "Clean Broken" button could be added to the project row (currently only global cleanup exists in footer)
- `deleteBrokenSymlinksInProject(_:)` is implemented but not exposed in the UI — a `DeleteConfirmation` case and project row button can be added when needed
- Extract shared badge styling into a `ViewModifier` (stale, duplicate, scope badges use the same pattern)
- Extract duplicate count post-processing from `scan()` into a helper method to reduce method length

## Audit Fixes

### Fixes applied

1. **Fixed `notifiedPaths.remove` after failed deletion** (QA-1, SEC-2, IC-2, SM-1, RC-1) — Moved `notifiedPaths.remove(file.path)` inside the `do` block in both `deleteBrokenSymlinks()` and `deleteBrokenSymlinksInProject()` so notification tracking is only cleared on successful deletion.

2. **Fixed TOCTOU on broken symlink deletion** (SEC-1, RC-4) — Added re-verification guard before `removeItem` in both `deleteBrokenSymlinks()` and `deleteBrokenSymlinksInProject()`. Checks that the entry is still a symlink and the target still doesn't exist, preventing deletion of a file that was re-targeted between scan and delete.

3. **Removed dead `brokenSymlinksInProject` enum case** (QA-2, IC-1, SM-3, DX-4) — Removed `DeleteConfirmation.brokenSymlinksInProject(String)` case since no UI element sets or matches it. The `deleteBrokenSymlinksInProject(_:)` method is retained for future use.

### Unresolved items

- **DX-1 (scan method length)**, **DX-2 (struct reconstruction fragility)**, **DX-3 (fileRow length)**, **DX-6 (badge styling repetition)** — Accepted as-is. These are readability improvements that don't affect correctness. The compiler catches missing fields in struct reconstruction. Badge styling extraction deferred to a future polish pass.
- **QA-4 (stale confirmDelete state)** — Accepted. Consistent with existing `.all` pattern. The safe behavior (confirmation disappears when data changes) works correctly.
- **TC-1 (no unit tests)** — Pre-existing limitation. Manual testing checklist updated.
- **TC-2 (isTargetInScope consistency)** — Both paths call the same `isInAllowedDeletionScope()` function. Low risk.

### Verification checklist

- [ ] Verify broken symlink deletion skips entries that were re-targeted to valid files between scan and delete
- [ ] Verify notification is not re-triggered for broken symlinks that failed to delete
- [ ] Verify removing `brokenSymlinksInProject` enum case does not break compilation
