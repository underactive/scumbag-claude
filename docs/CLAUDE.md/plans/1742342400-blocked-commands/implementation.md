# Implementation: Blocked Commands (Watchdog Extension)

## Files Changed

- `Sources/ClaudeTmpMonitor/MonitorService.swift` — Added `SettingsKey.watchdogBlockedCommands`
- `Sources/ClaudeTmpMonitor/WatchdogService.swift` — Added `blockedCommands` property, `defaultBlockedCommands`, `addBlockedCommand(_:)`, `removeBlockedCommand(at:)`, and updated `generateHookScript()` with `BLOCKED_CMDS` array and position-aware regex check
- `Sources/ClaudeTmpMonitor/SettingsView.swift` — Added `blockedCommandsSection` UI with list, remove buttons, inline text field + "Add" button
- `Sources/ClaudeTmpMonitor/App.swift` — Increased settings window height from 450 to 550
- `CLAUDE.md` — Updated settings list, watchdog subsystem description
- `docs/CLAUDE.md/testing-checklist.md` — Added 13 blocked commands test items
- `docs/CLAUDE.md/version-history.md` — Added v0.4.1 entry

## Summary

Implemented as planned. The blocked commands check is injected at the top of the Bash tool section in the generated hook script, before destructive pattern detection. Uses regex `(^|[|;&]\s*)${cmd}(\s|$)` to match commands only at command positions (start of line or after pipe/semicolon/ampersand), avoiding false positives on path arguments like `/etc/passwd`.

The UI follows the same visual pattern as the directory allowlist (bordered VStack, monospaced font, minus buttons) but uses an inline TextField + "Add" button instead of NSOpenPanel since blocked commands are plain strings, not filesystem paths.

## Verification

1. `swift build` — succeeds with no warnings
2. Code review of generated hook script logic confirms:
   - `BLOCKED_CMDS` array is populated from `blockedCommands` property
   - Check runs before destructive pattern detection
   - Regex correctly handles: start of line, after pipe, after semicolon, after ampersand
   - Blocked operations trigger notification, log, and exit 2

## Follow-ups

- None identified. The implementation matches the plan exactly.

## Audit Fixes

### Fixes Applied

1. **Input validation for blocked command names** (Security #1/#3, QA #1, Interface #4, Resource #4) — Added `[a-zA-Z0-9_-]` character validation in `addBlockedCommand()` to prevent regex metacharacter injection and shell injection via newlines/control characters.
2. **Load-time sanitization** (State Mgmt #4b) — Added filtering of `blockedCommands` loaded from UserDefaults at init time, applying the same `[a-zA-Z0-9_-]` validation to guard against manually tampered plist values.
3. **Settings window resizable** (QA #3, DX #5.1) — Added `.resizable` to settings window `styleMask` so users with many blocked commands can resize the window.
4. **Leading whitespace regex bypass** (Testing #4) — Changed regex from `(^|[|;&]\s*)` to `(^\s*|[|;&]\s*)` so indented commands like `  sudo rm -rf /` are correctly caught.
5. **Doc comment on defaultBlockedCommands** (DX #4.1) — Added rationale comment explaining selection criteria: commands that escalate privileges, alter system boot/security state, or destroy disks.
6. **Additional testing checklist items** (Testing #1/#3/#6/#9/#10/#11/#12) — Added 8 more test items covering semicolons, leading whitespace, end-of-line, empty list, argument position, disabled-state modification, UI visibility, and Enter key submission.

### Verification Checklist

- [x] `swift build` succeeds after all fixes
- [ ] Verify `addBlockedCommand("c++")` is rejected (contains `+`)
- [ ] Verify `addBlockedCommand("foo.bar")` is rejected (contains `.`)
- [ ] Verify values loaded from UserDefaults with invalid characters are filtered out
- [ ] Verify `  sudo rm -rf /` is blocked by updated regex (leading whitespace handled)
- [ ] Verify settings window can be resized by dragging the corner
