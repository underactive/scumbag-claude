# Plan: Comprehensive Audit Remediation (v0.2.0)

## Objective

Address ~40 findings from the 10-agent audit of v0.1.0 in a single implementation pass. Covers security, crash prevention, state management, code quality, UI/UX, accessibility, and deprecated API fixes across all 3 source files and Info.plist.

## Changes

### MonitorService.swift
- `SettingsKey` enum with static string constants for all UserDefaults keys
- `isInAllowedDeletionScope()` path validation for symlink target deletion
- Settings clamping in `init()` and `didSet` blocks with recursion guards
- `UInt64(clamping:)` for threshold byte conversion
- `warningBytes` / `criticalBytes` computed properties
- `deleteAllProjects()` batch method (single scan at end)
- `lastDeleteError` / `notificationsDenied` published properties
- `notifiedPaths` pruning at end of each scan cycle
- Timer `.tolerance` for energy efficiency; `deinit` for timer cleanup
- `launchAtLogin` re-entrancy guard; `scanIntervalSeconds` oldValue guard
- Deferred first scan via `Task { @MainActor }`
- Fixed relative symlink resolution (parent directory, not project root)
- Path validation in `scan()` via `resolveRealPath()`
- Removed dead `effectiveSize` and `isOutputFile` properties

### ContentView.swift
- `DeleteConfirmation` typed enum replacing `String?` confirm state
- Pluralization fix for file counts
- Removed `.opacity(0.6)` on secondary colors (contrast)
- Added `minHeight: 60` to ScrollView
- Accessibility labels on all icon-only buttons
- Keyboard shortcuts: Cmd+R (refresh), Cmd+, (settings), Cmd+Q (quit)
- `settingRow` simplified: removed `range` parameter and `onChange` (clamping in MonitorService)
- TextField uses label string for screen reader association
- Decorative dot separators marked `.accessibilityHidden(true)`
- Uses `monitor.warningBytes` / `criticalBytes` in `sizeColor()`
- Shows `lastDeleteError` in footer
- Shows notification permission warning in settings
- Uses `deleteAllProjects()` for Clean All

### App.swift
- Cached menubar icon as `private static let cachedMenuBarImage`
- Added `.accessibilityLabel("Scumbag Claude status")` to menubar label

### Info.plist
- Bumped version to 0.2.0
- Added `NSPrincipalClass` = `NSApplication`
- Added `CFBundleInfoDictionaryVersion` = `6.0`
- Removed deprecated `NSUserNotificationAlertStyle`

### CLAUDE.md
- Updated version, settings docs, file deletion docs, known issues

## Dependencies
1. MonitorService.swift first (ContentView depends on new properties)
2. ContentView.swift second
3. App.swift and Info.plist (independent)
4. CLAUDE.md and docs last

## Risks / Open Questions
- **SEC-C1 (path validation)**: If the allowlist is too narrow, legitimate deletions could fail silently. Mitigated by covering both known target paths and always removing the symlink entry itself.
- **TOCTOU on delete**: Intentionally deferred — re-resolving at delete time adds significant complexity for a low-probability race condition.
