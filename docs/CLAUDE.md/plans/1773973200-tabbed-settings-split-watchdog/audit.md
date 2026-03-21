# Audit Report: Tabbed Settings with Split Watchdog Toggles

## Files changed

- `Sources/ClaudeTmpMonitor/WatchdogService.swift` — Security, QA, Interface, Resource, DX findings
- `Sources/ClaudeTmpMonitor/SettingsView.swift` — QA, DX findings

## 1. QA Audit

### [FIXED] Finding QA-4 (High): `regenerateHookScript()` silently no-ops when hook script externally deleted
`WatchdogService.swift:231-232` — When `allowedDirectories` or `blockedCommands` change, `regenerateHookScript()` guards on `fileManager.fileExists(atPath: hookScriptPath)` and returns silently if missing. Changed to fall through to `installHook()` when script file is missing but hook should be installed.

### [FIXED] Finding QA-9 (High): `ForEach` uses `.offset` as id, unstable during mutation
`SettingsView.swift:77, 144` — Both directory and command lists used `id: \.offset` which is unstable when items are removed (indices shift). Changed to `id: \.element` since both lists enforce uniqueness via `addDirectory`/`addBlockedCommand`.

### Finding QA-1 (Medium): Bash section always emitted even when neither feature needs it
Not a bug — `generateHookScript()` is only called when `hookShouldBeInstalled` is true (at least one feature enabled), so the Bash block always has content.

### Finding QA-3 (Medium): Migration requires both new keys to be absent
Accepted as-is. Partial key state requires extraordinary circumstances (external UserDefaults editing). Default of `false` for missing key is safe.

## 2. Security Audit

### [FIXED] Finding S1 (Low): `shellEscape()` does not strip newline/control characters
`WatchdogService.swift:247-254` — A directory path containing `\n` could inject arbitrary bash into the generated script. Added `\n` and `\r` stripping to `shellEscape()`.

### Finding S5 (Info): `watchdog.log` grows unboundedly
Pre-existing, not introduced by this change.

## 3. Interface Contract Audit

No broken references to old `isEnabled` found. Migration is complete. All matcher combinations verified correct.

### Finding IF-4 (Low): `regenerateHookScript()` no-ops when script externally deleted
Same as QA-4. [FIXED]

## 4. State Management Audit

No state management bugs found. `@MainActor` isolation prevents all concurrent mutation. `Published(wrappedValue:)` in init correctly avoids triggering didSet. `hookShouldBeInstalled` computed property always reads live state. Rapid toggling produces sequential (not concurrent) calls — redundant but correct.

## 5. Resource & Concurrency Audit

No defects found. `@MainActor` isolation is complete. File writes use Foundation atomic APIs. No re-entrancy issues in `reconcileHookState()` chain.

### [FIXED] Finding R-5 (Info): Unnecessary `patchClaudeSettings` call in `regenerateHookScript()`
`WatchdogService.swift:238` — The matcher depends on `fileOpsEnabled`, not directories/commands, so patching settings when only dirs/commands change is redundant. Removed the `patchClaudeSettings(install: true)` call from `regenerateHookScript()`. The externally-deleted-script case now falls through to `installHook()` which handles both script + settings.

## 6. Testing Coverage Audit

Testing checklist updated with 13 new items for the tabbed settings feature. Stale items from old flat layout updated.

### Gaps addressed:
- Added inverse test cases (file ops only allows blocked commands, commands only allows destructive file ops)
- Added toggle roundtrip test (enable → disable → enable other)
- Updated stale references to old "under a divider" layout

## 7. DX & Maintainability Audit

### [FIXED] Finding DX-2.2 (Low): `installHook()` and `uninstallHook()` have unnecessary internal access
`WatchdogService.swift:161, 200` — Both methods are only called from `reconcileHookState()` and `init()`. Changed to `private`.

### Finding DX-1.1 (Medium): `generateHookScript()` exceeds 50 lines (~290 lines)
Accepted as-is. The conditional script building is inherently long; decomposing into sub-generators would add indirection without improving clarity since sections share the `script` variable.

### Finding DX-3.1 (Low): Naming inconsistency (`fileOpsEnabled` vs `commandWatchdogEnabled`)
Accepted as-is. These are persisted to UserDefaults — renaming would require another migration for cosmetic benefit.

### Finding DX-3.3 (Medium): Duplicated list-with-remove pattern in SettingsView
Accepted as-is. The two lists differ enough (directory picker vs text field input) that a generic abstraction would be over-engineering for two instances.

### Finding DX-4.4 (Medium): CLAUDE.md out of sync
Already fixed by documentation agent before audit ran.
