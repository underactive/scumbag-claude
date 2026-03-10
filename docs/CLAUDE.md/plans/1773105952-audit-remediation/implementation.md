# Implementation: Comprehensive Audit Remediation (v0.2.0)

## Files Changed

- `Sources/ClaudeTmpMonitor/MonitorService.swift` — Major rewrite: added SettingsKey enum, path validation, settings clamping, batch delete, computed byte properties, notification permission check, timer tolerance/deinit, notifiedPaths pruning, deferred first scan, relative symlink fix, removed dead properties
- `Sources/ClaudeTmpMonitor/ContentView.swift` — Added DeleteConfirmation enum, accessibility labels, keyboard shortcuts, pluralization fix, notification warning, delete error display, simplified settingRow, uses computed byte properties
- `Sources/ClaudeTmpMonitor/App.swift` — Cached menubar icon as static let, added accessibility label to menubar
- `Info.plist` — Version bump to 0.2.0, added NSPrincipalClass and CFBundleInfoDictionaryVersion, removed deprecated NSUserNotificationAlertStyle
- `CLAUDE.md` — Updated version, settings docs, file deletion docs, known issues
- `docs/CLAUDE.md/testing-checklist.md` — Complete rewrite with behavioral test items for all new features
- `docs/CLAUDE.md/version-history.md` — Added v0.2.0 entry

## Summary

Implemented ~40 fixes from the comprehensive audit in a single pass:

**Security:** Path validation allowlist on symlink target deletion, scan-time path verification via realpath resolution, fixed relative symlink resolution to use parent directory.

**Crash Prevention:** Settings clamped at load and in didSet, UInt64(clamping:) for byte conversion.

**State Management:** LaunchAtLogin re-entrancy guard, scanIntervalSeconds oldValue guard to prevent timer restart spam, deferred first scan, notifiedPaths pruning per scan cycle.

**Code Quality:** SettingsKey enum, warningBytes/criticalBytes computed properties, deleteAllProjects batch method, removed dead MonitoredFile properties, lastDeleteError/notificationsDenied published properties.

**UI/UX:** Typed DeleteConfirmation enum, pluralization fixes, delete error display in footer, notification permission warning in settings, removed opacity on secondary colors.

**Accessibility:** Labels on all icon-only buttons, keyboard shortcuts (Cmd+R/,/Q), accessibilityHidden on decorative separators, TextField labels for screen readers, menubar accessibility label.

**Info.plist:** NSPrincipalClass, CFBundleInfoDictionaryVersion, removed deprecated NSUserNotificationAlertStyle.

No deviations from the plan.

## Verification

- `make build` — compiles cleanly with zero warnings
- All files reviewed for consistency after changes
- Version bumped in Info.plist and CLAUDE.md simultaneously

## Follow-ups

- TOCTOU re-resolve at delete time (deferred — separate plan)
- Test target creation (separate plan)
- Full localization infrastructure (separate plan)
- Async scan refactor (separate plan)

## Audit Fixes

### Fixes Applied

1. **Restored `scan()` call in `deleteProject()`** — Fixed QA-1/SM-1: `deleteProject()` was missing the trailing `scan()` call that refreshes the projects list after deletion, leaving stale UI state until the next timer tick.

2. **Surfaced symlink target deletion errors** — Fixed QA-4/IC-1: All three deletion methods (`deleteFile`, `deleteProject`, `deleteAllProjects`) now capture and report symlink target deletion errors via `lastDeleteError` instead of silently swallowing them with `try?`.

3. **Added scan re-entrancy guard** — Fixed SM-3/RC-3: Added `guard !isScanning else { return }` at the top of `scan()` to prevent overlapping scans when timer callbacks and manual refreshes coincide.

### Verification Checklist

- [x] `make build` compiles cleanly after all audit fixes
- [ ] Verify `deleteProject()` refreshes the project list immediately after deletion
- [ ] Verify symlink target deletion errors appear in the footer error text
- [ ] Verify rapid clicking of refresh button doesn't cause overlapping scans

### Unresolved Items

All remaining audit findings were accepted as-is or deferred to separate plans. See `audit.md` for detailed rationale on each.
