# Plan: Blocked Commands (Watchdog Extension)

## Objective

Add a second layer to the file write watchdog that blocks *what* Claude runs — inherently dangerous commands (e.g., `passwd`, `sudo`, `shutdown`) that should never be executed by an AI assistant, regardless of the target directory. This check runs **before** the directory-based path checks in the Bash tool section.

## Changes

### 1. `Sources/ClaudeTmpMonitor/MonitorService.swift`
- Add `SettingsKey.watchdogBlockedCommands` to the `SettingsKey` enum

### 2. `Sources/ClaudeTmpMonitor/WatchdogService.swift`
- Add `@Published var blockedCommands: [String]` with `didSet` UserDefaults persistence
- Add `static let defaultBlockedCommands` with: passwd, sudo, su, shutdown, reboot, halt, poweroff, mkfs, newfs, diskutil, csrutil, nvram, dscl
- Load from UserDefaults in init via `Published(wrappedValue:)`
- Add `addBlockedCommand(_:)` and `removeBlockedCommand(at:)` methods
- Update `generateHookScript()` to bake `BLOCKED_CMDS` array and add check before destructive pattern detection
- Regex pattern: `(^|[|;&]\s*)${cmd}(\s|$)` — matches command at command position, avoids path false positives

### 3. `Sources/ClaudeTmpMonitor/SettingsView.swift`
- Add blocked commands subsection with scrollable list, remove buttons, and inline text field + "Add" button

### 4. `Sources/ClaudeTmpMonitor/App.swift`
- Increase settings window height from 450 to 550

### 5. Documentation
- Update CLAUDE.md settings section and watchdog subsystem description
- Update version-history.md, testing-checklist.md

## Dependencies

No ordering constraints between code changes. Documentation must follow code changes.

## Risks / Open Questions

- Regex approach `(^|[|;&]\s*)${cmd}(\s|$)` won't catch commands invoked via variables, subshells, or aliases — consistent with existing known limitation of best-effort Bash parsing
- Default blocked list is opinionated; users can customize via Settings UI
