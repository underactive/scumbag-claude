# Audit Report: Symlink Visibility & Broken Symlink Cleanup

## Files changed

- `Sources/ClaudeTmpMonitor/MonitorService.swift`
- `Sources/ClaudeTmpMonitor/ContentView.swift`

---

## 1. QA Audit

### [FIXED] QA-1: `notifiedPaths.remove` called after failed deletion (Low)
`notifiedPaths.remove(file.path)` was outside the `do` block in `deleteBrokenSymlinks()` and `deleteBrokenSymlinksInProject()`, clearing notification tracking even when deletion failed.

### [FIXED] QA-2: Dead code — `DeleteConfirmation.brokenSymlinksInProject` unreachable (Medium)
The enum case and corresponding `deleteBrokenSymlinksInProject(_:)` method had no UI entry point. Enum case removed; method retained for future use.

### QA-3: Duplicate count rebuild allocates full project copies (Low)
When duplicates exist, all `ClaudeProject` structs are rebuilt even if none of their files changed. Negligible for realistic workloads.

### QA-4: Confirm/cancel state persists after data changes (Low)
If broken symlinks disappear between clicking "Clean Broken" and confirming, the UI hides the buttons but `confirmDelete` remains `.brokenSymlinks`. If broken symlinks reappear, confirm buttons show without re-clicking. Consistent with existing `.all` pattern — accepted as-is.

---

## 2. Security Audit

### [FIXED] SEC-1: TOCTOU — broken symlink state not re-verified before deletion (Low)
Between scan and delete, a broken symlink could be re-targeted to a valid file. Added re-verification guard checking that the entry is still a symlink and target still doesn't exist.

### [FIXED] SEC-2: `notifiedPaths` cleared after failed deletion (Low)
Same as QA-1. Fixed by moving `notifiedPaths.remove` inside `do` block.

### SEC-3: `deleteBrokenSymlinksInProject` operates on stale project reference (Low)
The method receives a `ClaudeProject` by value which may be stale. Consistent with existing `deleteProject(_:)` pattern and mitigated by `/private/tmp/claude-*` path constraint. Accepted as-is (Known Issue #3).

---

## 3. Interface Contract Audit

### [FIXED] IC-1: `brokenSymlinksInProject` enum case defined but never matched (Medium)
Same as QA-2. Fixed.

### [FIXED] IC-2: `notifiedPaths` cleared after failed deletion (Low)
Same as QA-1. Fixed.

### IC-3: Stale project snapshot used at deletion time (Low)
Same as SEC-3. Accepted as-is.

### IC-4: Single `confirmDelete` state — competing triggers cancel silently (Low)
Only one confirmation can be active. Clicking "Clean Broken" replaces any active file/project confirmation. This is the intended single-selection design.

---

## 4. State Management Audit

### [FIXED] SM-1: `notifiedPaths` cleared after failed deletion (Low)
Same as QA-1. Fixed.

### SM-2: Full project graph reconstructed when any duplicate exists (Informational)
Inner guard avoids unnecessary `MonitoredFile` reconstruction; outer `ClaudeProject` always rebuilt. Negligible cost.

### [FIXED] SM-3: `brokenSymlinksInProject` enum case is dead state (Low)
Same as QA-2. Fixed.

### SM-4: `brokenSymlinkCount` recomputes on every render (Informational)
O(projects * files) in render path. Trivial for realistic counts.

### SM-5: `@MainActor` isolation properly maintained (Positive)
No concurrent writer issues.

---

## 5. Resource & Concurrency Audit

### [FIXED] RC-1: `notifiedPaths.remove` after failed deletion (Low)
Same as QA-1. Fixed.

### RC-2: `scan()` mutates `projects` after iteration (Low)
Safe due to Swift COW semantics + `@MainActor` synchronous execution. No action needed.

### RC-3: `deinit` accesses actor-isolated state (Medium, pre-existing)
Pre-existing issue — `deinit` is nonisolated but accesses `@MainActor` properties. Practically safe since MonitorService is a singleton. Not introduced by this change.

### [FIXED] RC-4: No TOCTOU protection on broken symlink deletion (Low)
Same as SEC-1. Fixed.

---

## 6. Testing Coverage Audit

### TC-1: No unit tests for new logic (Medium)
No test target exists. Duplicate count computation, `isTargetInScope`, and broken symlink deletion are untestable by automation. Manual testing checklist has been updated to cover UI-facing behavior.

### TC-2: `isTargetInScope` vs `isInAllowedDeletionScope()` consistency gap (Medium)
`isTargetInScope` is computed at scan time; `deleteFile()` independently calls `isInAllowedDeletionScope()` at delete time. Both use the same underlying method, so they agree — but no test verifies this invariant. Accepted as low-risk since both paths call the same function.

### TC-3: Missing checklist items for edge cases (Low)
Duplicate count decrease after deletion, deletion behavior for out-of-scope files (not just visual). Deferred — existing checklist items partially cover these scenarios.

---

## 7. DX & Maintainability Audit

### DX-1: `scan()` is 143 lines (Medium)
Duplicate count post-processing could be extracted into a helper. Accepted as-is for now — the logic is self-contained and well-commented.

### DX-2: Fragile full-struct reconstruction (Medium)
Updating `duplicateCount` requires reconstructing the full `MonitoredFile` (12 fields). Adding a new field to the struct requires updating this reconstruction site. Accepted — the compiler will catch missing fields.

### DX-3: `fileRow` is 87 lines with dense badge styling (Low)
Three badges (stale, duplicate, scope) use the same styling pattern. Could be a shared `ViewModifier`. Accepted for now.

### [FIXED] DX-4: `brokenSymlinksInProject` enum case and method unreachable (Medium)
Same as QA-2. Enum case removed.

### DX-5: `isTargetInScope` name is slightly ambiguous (Low)
Inline comment clarifies meaning. Accepted as-is.

### DX-6: Repeated badge styling pattern (Low)
Three badges share similar `.font/.foregroundColor/.padding/.background/.cornerRadius` chains. Could be extracted into a helper. Deferred to a future polish pass.
