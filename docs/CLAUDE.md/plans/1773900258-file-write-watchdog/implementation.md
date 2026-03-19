# Implementation: File Write Watchdog

## Files Changed

- `Sources/ClaudeTmpMonitor/MonitorService.swift` — Added `SettingsKey.watchdogEnabled` and `SettingsKey.watchdogAllowedDirectories`
- `Sources/ClaudeTmpMonitor/WatchdogService.swift` — **NEW** — Complete watchdog service with hook lifecycle management, script generation, Claude settings patching
- `Sources/ClaudeTmpMonitor/App.swift` — Added `WatchdogService` instance, wired as `.environmentObject()` to ContentView and SettingsView, increased settings window height (330 → 450)
- `Sources/ClaudeTmpMonitor/SettingsView.swift` — Added watchdog section: toggle, directory list with add/remove, hook status indicator
- `Sources/ClaudeTmpMonitor/ContentView.swift` — No changes (watchdogService environment object removed during audit)
- `Info.plist` — Version bump 0.4.0 → 0.5.0
- `CLAUDE.md` — Updated version, core files (8→9), added WatchdogService description, added Watchdog subsystem section, updated Data Flow, added settings keys, added file inventory entry, added known issues
- `docs/CLAUDE.md/version-history.md` — Added v0.5.0 entry
- `docs/CLAUDE.md/testing-checklist.md` — Added File Write Watchdog section (23 test items)
- `docs/CLAUDE.md/future-improvements.md` — Marked File Write Watchdog as done
- `docs/CLAUDE.md/plans/1773900258-file-write-watchdog/plan.md` — Plan document

## Summary

Implemented the File Write Watchdog as planned. Key implementation details:

1. **JXA approach changed during implementation**: The original plan used a heredoc-based JXA stdin reader (`availableData` in a loop). Testing revealed this didn't work reliably when piped input and heredoc stdin conflicted. Switched to the `run(argv)` pattern where JSON is passed as an argument via `--`, which is simpler and more reliable.

2. **Hook script generation**: The bash script is generated as a Swift string literal with expanded directory paths baked in. Uses `osascript -l JavaScript -e '...'` with single-quoted JXA for zero escaping complexity. The `run(argv)` pattern avoids stdin entirely.

3. **Settings patching**: Read-modify-write of `~/.claude/settings.local.json` using `JSONSerialization` with `.prettyPrinted` and `.sortedKeys`. Creates `~/.claude/` directory if absent. Uses atomic writes.

4. **Fail-open design**: If JXA parsing fails (malformed JSON, osascript error), the hook exits 0 to allow the operation. This ensures the watchdog never becomes a blocking issue.

## Verification

1. **Build**: `swift build` and `make build` (release) both succeed with zero warnings
2. **JXA parsing tested**: Verified `osascript -l JavaScript -e '...' -- "$INPUT"` correctly parses Write, Edit, and Bash tool inputs with special characters
3. **All source files compile**: 9 Swift source files compile without errors
4. **Version consistency**: Info.plist (0.5.0) and CLAUDE.md (0.5.0) are in sync

## Follow-ups

- End-to-end testing with a live Claude Code session (hook install → block → allow → uninstall cycle)
- Consider adding a "View Log" button in Settings to open the watchdog log file
- Consider rate-limiting notifications to avoid spam during rapid Claude tool calls

## Audit Fixes

### Fixes Applied

1. **Fixed directory traversal bypass** (Security §1, QA §7): Replaced filesystem-dependent path normalization (`cd` + `pwd -P`) with pure-string `normalize_path()` function that uses `read -ra` to split on `/` and resolve `.`/`..` segments. Also added `check_allowed()` helper that appends trailing `/` to both the target path and allowed directories before prefix comparison, preventing `/DevelopmentEvil` from matching `/Development`.

2. **Fixed shell injection in generated script** (Security §6, QA §4): Added `shellEscape()` method that escapes `\`, `"`, `$`, and `` ` `` before interpolating directory paths into the bash script string.

3. **Fixed AppleScript injection in notifications** (Security §2): Replaced inline `osascript` notification commands with `notify_blocked()` function that strips `"`, `\`, `` ` ``, and `$` from displayed text via `tr -d`.

4. **Fixed `didSet` firing during init** (State §1): Replaced direct property assignment in `init()` with `Published(wrappedValue:)` initializer to avoid triggering `installHook()` before `allowedDirectories` is loaded. Eliminates triple-write of hook script during startup.

5. **Fixed corrupted settings.local.json silently overwritten** (Interface §2.1): `patchClaudeSettings` now distinguishes "file doesn't exist" from "file has invalid JSON". For invalid JSON, it sets `lastError` and returns early instead of overwriting.

6. **Added `matcher` field to hook entry** (Interface §1.1): Hook now includes `"matcher": "Write|Edit|Bash"` so it only fires for relevant tool types, avoiding the overhead of spawning osascript for read-only tools.

7. **Fixed `checkHookStatus()` double-notify** (State §4): Removed unconditional `hookInstalled = false` at method start. Now computes result locally via guard chain and assigns once.

8. **Removed unused `watchdogService` from ContentView** (State §5, QA §14): Removed `@EnvironmentObject var watchdogService` from ContentView and its `.environmentObject(watchdogService)` injection in App.swift's popover setup. Eliminates unnecessary SwiftUI re-renders and latent crash risk.

9. **Fixed `lastError` access level** (State §7): Changed from `@Published var` to `@Published private(set) var` for consistency with `hookInstalled`.

10. **Removed dead `logFilePath` property** (DX §2): Computed property was never referenced in Swift code.

11. **Changed hook script permissions to 0700** (Security §7): Principle of least privilege — only the current user needs execute access.

12. **Added 6 additional testing checklist items** (Testing §1): Covers empty allowlist, pre-existing hooks, cold start, corrupted JSON, path traversal, and prefix matching edge cases.

### Verification Checklist

- [x] `swift build` succeeds after all fixes
- [x] `make build` (release) succeeds
- [x] Path normalization tested in bash: resolves `..`, `.`, `//`, `~` correctly
- [x] Prefix matching tested: `/DevelopmentEvil` correctly blocked, `/Development/project` allowed
- [ ] End-to-end hook install/block/allow/uninstall cycle with live Claude Code session

### Unresolved Items

- **Bash command parsing is best-effort** (QA §5, Security §5): Accepted as known limitation. Documented in CLAUDE.md Known Issues.
- **`|` delimiter fragility for paths containing `|`** (Interface §3.2): Extremely rare edge case. Accepted.
- **Multi-line bash commands truncated** (Interface §3.5): Accepted. The Write/Edit checks are the primary defense.
- **Synchronous file I/O on main thread** (Resource §1): Acceptable for small files. Can be moved to background if latency observed.
- **Non-resizable settings window** (QA §7): Acceptable for current directory list sizes.
- **Unbounded log file growth** (QA §9): Blocked operations should be rare. Log rotation is a future improvement.
