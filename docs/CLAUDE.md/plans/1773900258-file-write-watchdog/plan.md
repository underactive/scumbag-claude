# Plan: File Write Watchdog

## Objective

Add a safety feature that blocks and notifies when any Claude Code session attempts to write, edit, or delete files outside of user-whitelisted directories. Uses Claude Code's PreToolUse hook system — a shell script that runs before Write, Edit, and Bash tool calls, checks file paths against an allowlist, and blocks operations outside allowed directories (exit code 2). The Scumbag Claude app manages the hook lifecycle and provides a Settings UI for configuring the directory whitelist.

## Changes

### 1. `Sources/ClaudeTmpMonitor/MonitorService.swift` (MODIFY)
- Add `SettingsKey.watchdogEnabled` and `SettingsKey.watchdogAllowedDirectories` to the `SettingsKey` enum

### 2. `Sources/ClaudeTmpMonitor/WatchdogService.swift` (NEW)
- New `@MainActor class WatchdogService: ObservableObject`
- Settings: `isEnabled`, `allowedDirectories` persisted via UserDefaults
- Hook lifecycle: `installHook()`, `uninstallHook()`, `checkHookStatus()`
- Hook script generation via `generateHookScript()` — bash script with JXA JSON parsing
- Claude settings patching: read-modify-write `~/.claude/settings.local.json`

### 3. `Sources/ClaudeTmpMonitor/App.swift` (MODIFY)
- Create `WatchdogService` instance in `AppDelegate`
- Pass as `.environmentObject()` to ContentView and SettingsView
- Increase settings window height

### 4. `Sources/ClaudeTmpMonitor/SettingsView.swift` (MODIFY)
- Add Watchdog section with toggle, directory list, add/remove controls, hook status indicator

### 5. `Sources/ClaudeTmpMonitor/ContentView.swift` (MODIFY)
- Add `@EnvironmentObject var watchdogService: WatchdogService`

### 6. Documentation updates
- CLAUDE.md, Info.plist, version-history, testing-checklist, future-improvements

## Dependencies

1. MonitorService.swift — SettingsKey additions (no deps)
2. WatchdogService.swift — new file (depends on #1)
3. App.swift — wire WatchdogService (depends on #2)
4. SettingsView.swift — add watchdog section (depends on #2)
5. ContentView.swift — add environment object (depends on #2)
6. Documentation — after all code changes

## Risks / Open Questions

1. **Bash parsing is best-effort** — Shell commands are inherently ambiguous to parse. The watchdog catches obvious `rm /path` patterns but won't catch every possible destructive command. Acceptable as a safety net, not a sandbox.
2. **`osascript -l JavaScript` latency** — JXA invocation adds ~50-100ms to each tool call. Acceptable for a pre-execution hook.
3. **Race condition on `settings.local.json`** — If user edits the file while app writes, one edit could be lost. Mitigated by atomic writes.
4. **Hook persists independently of app** — If the app is uninstalled but `settings.local.json` isn't cleaned up, the hook will error on every Claude tool call.
