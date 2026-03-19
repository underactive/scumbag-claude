# Plan: Tabbed Settings View with Split Watchdog Toggles

## Objective

Refactor SettingsView into a TabView with 3 tabs (General, File Operations, Blocked Commands) and split the monolithic `watchdogEnabled` boolean into two independent toggles:

- **`fileOpsEnabled`** — Controls directory-based file operations checking (Write/Edit tool validation against the allowlist)
- **`commandWatchdogEnabled`** — Controls blocked commands enforcement (Bash tool validation against the blocked commands list)

This separation allows users to independently enable/disable file operation guards and command blocking, rather than being forced into an all-or-nothing watchdog mode. The tabbed layout organizes the growing settings surface into logical groups and prevents the single-scroll settings panel from becoming unwieldy.

## Changes

### `Sources/ClaudeTmpMonitor/WatchdogService.swift`
- Replace single `isEnabled` published property with two independent toggles: `fileOpsEnabled` and `commandWatchdogEnabled`
- Add `hookShouldBeInstalled` computed property that returns `true` when either toggle is on
- Add `reconcileHookState()` method that installs or removes the hook based on `hookShouldBeInstalled`
- Migrate from legacy `watchdogEnabled` UserDefaults key in `init()`: if the legacy key is `true`, enable both new toggles and clear the legacy key
- Update `generateHookScript()` to conditionally include sections:
  - Write/Edit path-checking section only emitted when `fileOpsEnabled` is true
  - Blocked commands loop only emitted when `commandWatchdogEnabled` is true
- Update tool matcher in generated script: `Write|Edit|Bash` when both enabled, `Write|Edit` when only file ops, `Bash` when only commands
- Wire both toggle `didSet` handlers to call `reconcileHookState()` and regenerate the script

### `Sources/ClaudeTmpMonitor/MonitorService.swift`
- Add `watchdogFileOpsEnabled` and `watchdogCommandWatchdogEnabled` to the `SettingsKey` enum
- Mark `watchdogEnabled` key as legacy with a comment

### `Sources/ClaudeTmpMonitor/SettingsView.swift`
- Complete rewrite from flat VStack to TabView with 3 tabs:
  - **General** — Threshold/interval settings, notifications toggle, launch at login toggle, history retention
  - **File Operations** — File ops watchdog toggle, directory allowlist management, hook status indicator, help text
  - **Blocked Commands** — Command watchdog toggle, blocked commands list with add/remove, hook status indicator, help text
- Extract shared `hookStatusView` used by both watchdog tabs
- Show contextual help text when each toggle is enabled, explaining what it does

### `Sources/ClaudeTmpMonitor/App.swift`
- Change settings window size from 350x550 to 420x480 to accommodate the tabbed layout

### `CLAUDE.md`
- Update SettingsView description to reflect tabbed layout with 3 tabs
- Update WatchdogService description to document split toggles, `hookShouldBeInstalled`, `reconcileHookState()`
- Update settings list: replace `watchdogEnabled` with `fileOpsEnabled` and `commandWatchdogEnabled`
- Update watchdog subsystem documentation to describe conditional script generation and adaptive matcher

## Dependencies

1. **WatchdogService changes must precede SettingsView** — The view binds to `fileOpsEnabled` and `commandWatchdogEnabled` published properties, so the service must expose them before the view can reference them.
2. **MonitorService SettingsKey additions should precede WatchdogService** — The new key constants should be defined before they are consumed, though in practice Swift compilation handles this as long as both are in the same module.

## Risks / Open Questions

1. **Migration from legacy `watchdogEnabled` key** — Users upgrading from v0.4.1 will have the old key in UserDefaults. The migration logic in `init()` must correctly detect the old key, set both new toggles, and remove the old key to prevent re-migration on subsequent launches. Edge case: if the old key was explicitly set to `false`, migration should not enable either toggle.
2. **Generated bash script correctness with conditional sections** — When only one toggle is enabled, the generated script must still be syntactically valid bash. The tool name matcher regex and the conditional blocks must compose correctly in all four states (both off = no hook, file ops only, commands only, both on).
3. **Hook reinstallation on toggle change** — Toggling either setting must regenerate the script and potentially install/uninstall the hook. The `reconcileHookState()` method must handle the transition from "one enabled" to "both disabled" (uninstall) and "both disabled" to "one enabled" (install) correctly.
4. **Window size change** — The new 420x480 size must accommodate all three tabs without scrolling on the longest tab. May need adjustment after visual testing.
