# Implementation: Tabbed Settings View with Split Watchdog Toggles

## Files Changed

### `Sources/ClaudeTmpMonitor/MonitorService.swift`
- Added `watchdogFileOpsEnabled` and `watchdogCommandWatchdogEnabled` constants to the `SettingsKey` enum
- Marked `watchdogEnabled` key as legacy with a `// Legacy — migrated in WatchdogService.init()` comment

### `Sources/ClaudeTmpMonitor/WatchdogService.swift`
- Replaced single `isEnabled` published property with two independent toggles: `fileOpsEnabled` and `commandWatchdogEnabled`
- Added `hookShouldBeInstalled` computed property returning `true` when either toggle is on
- Added `reconcileHookState()` method that installs the hook when `hookShouldBeInstalled` is true and removes it when false
- Added migration logic in `init()`: reads legacy `watchdogEnabled` key, if `true` enables both new toggles, then removes the legacy key
- Updated `generateHookScript()` with conditional sections:
  - Write/Edit path-checking section only emitted when `fileOpsEnabled` is true
  - Blocked commands loop only emitted when `commandWatchdogEnabled` is true
- Adaptive tool matcher in generated script: `Write|Edit|Bash` when both enabled, `Write|Edit` when only file ops, `Bash` when only commands
- Both toggle `didSet` handlers call `reconcileHookState()` and regenerate the script when the hook is installed

### `Sources/ClaudeTmpMonitor/SettingsView.swift`
- Complete rewrite from flat VStack layout to TabView with 3 tabs:
  - **General** tab: threshold/interval settings, notifications toggle, launch at login toggle, history retention
  - **File Operations** tab: file ops watchdog toggle, directory allowlist with add (NSOpenPanel) / remove controls, hook status indicator, contextual help text shown when toggle is on
  - **Blocked Commands** tab: command watchdog toggle, blocked commands list with inline text field add / remove controls, hook status indicator, contextual help text shown when toggle is on
- Extracted shared `hookStatusView` computed property used by both watchdog tabs to show green/red hook installation status
- Help text explains what each watchdog feature does when its toggle is enabled

### `Sources/ClaudeTmpMonitor/App.swift`
- Changed settings window size from 350x550 to 420x480 to accommodate the tabbed layout

### `CLAUDE.md`
- Updated SettingsView description to reflect tabbed layout with 3 tabs (General, File Operations, Blocked Commands)
- Updated WatchdogService description to document split toggles (`fileOpsEnabled`, `commandWatchdogEnabled`), `hookShouldBeInstalled` computed property, `reconcileHookState()` method, and conditional script generation
- Updated settings list: replaced `watchdogEnabled: Bool` with `fileOpsEnabled: Bool` and `commandWatchdogEnabled: Bool`
- Updated watchdog subsystem documentation to describe adaptive tool matcher and conditional section generation

## Summary

Implemented as planned with no deviations. The monolithic `watchdogEnabled` toggle was split into two independent toggles (`fileOpsEnabled` for Write/Edit directory checking, `commandWatchdogEnabled` for Bash blocked commands), and the SettingsView was refactored from a single scrollable VStack into a 3-tab TabView. Legacy migration ensures existing users who had the watchdog enabled get both new toggles turned on automatically. The generated hook script adapts its tool matcher and conditional sections based on which toggles are active.

## Verification

- `swift build` succeeds with zero errors and zero warnings
- Verified that the generated plan and implementation documents are consistent with the actual code changes

## Follow-ups

None identified.

## Audit Fixes

### Fixes applied

1. **Security S1:** Added `\n` and `\r` stripping to `shellEscape()` in `WatchdogService.swift` to prevent script injection via control characters in UserDefaults directory paths.
2. **QA-4 / Interface IF-4:** Changed `regenerateHookScript()` to fall through to `installHook()` when the hook script file is missing (instead of silently returning), ensuring directory/command changes trigger a full reinstall if the script was externally deleted.
3. **QA-9:** Changed `ForEach` identity from `id: \.offset` to `id: \.element` in both directory and command lists in `SettingsView.swift` for stable identity during mutations.
4. **Resource R-5 / DX 5.2:** Removed unnecessary `patchClaudeSettings(install: true)` call from `regenerateHookScript()` — the matcher depends on `fileOpsEnabled`, not directories/commands.
5. **DX-2.2:** Changed `installHook()` and `uninstallHook()` from internal to `private` access in `WatchdogService.swift`.

### Unresolved items

- **DX-1.1** (`generateHookScript()` length): Accepted — conditional script building is inherently long.
- **DX-3.1** (naming inconsistency): Accepted — renaming would require UserDefaults migration.
- **DX-3.3** (duplicated list pattern): Accepted — lists differ enough that abstraction is premature.

### Verification checklist

- [x] `swift build` succeeds after all fixes
- [ ] Verify `shellEscape` strips `\n`/`\r` from directory paths containing control characters
- [ ] Verify `regenerateHookScript()` recreates script when file is externally deleted (delete hook script manually, change a directory, verify script is recreated)
- [ ] Verify `ForEach` deletion animations are correct (remove middle item from directory list, confirm correct item disappears)
- [ ] Verify `installHook()` and `uninstallHook()` are not called from outside `WatchdogService`
