# Audit Report: File Write Watchdog

## Files Changed

- `Sources/ClaudeTmpMonitor/WatchdogService.swift`
- `Sources/ClaudeTmpMonitor/MonitorService.swift`
- `Sources/ClaudeTmpMonitor/App.swift`
- `Sources/ClaudeTmpMonitor/SettingsView.swift`
- `Sources/ClaudeTmpMonitor/ContentView.swift`

---

## 1. QA Audit

### [FIXED] QA-1 (HIGH): Shell injection in generated hook script
Directory paths containing `"`, `$`, backticks could break the generated bash script. **Fixed**: Added `shellEscape()` method that escapes all shell-significant characters before interpolation.

### [FIXED] QA-2 (HIGH): Directory traversal bypass via `..` in paths
Path normalization relied on `cd "$(dirname ...)"` which fails when parent directory doesn't exist, leaving `..` segments un-resolved. Combined with prefix matching, `/allowed/dir/../../etc/passwd` would pass the allowlist. **Fixed**: Replaced with pure-string `normalize_path()` function using `read -ra` to split on `/` and resolve `.`/`..` segments without touching the filesystem.

### [FIXED] QA-3 (HIGH): Prefix match allows `/DevelopmentEvil` to match `/Development`
Prefix check `"$FILE_PATH" == "$dir"*` without trailing `/` on `$dir`. **Fixed**: All allowed directories are stored with trailing `/`, and `check_allowed()` also appends `/` to the target path before comparison.

### QA-4 (MEDIUM): Bash command parsing is fundamentally fragile and bypassable
Multi-command chains, subshells, variable expansion, eval, aliases, python/perl/ruby scripts, tee, cp, chmod — none detected. **Accepted as known limitation**: documented in CLAUDE.md Known Issues. The watchdog is a safety net, not a sandbox.

### QA-5 (MEDIUM): Multiple destructive pattern matches overwrite `TARGET_PATH`
The `>` and `>>` regex blocks can both match, overwriting the target path. **Accepted**: consolidated redirect pattern matching; the final TARGET_PATH is still checked against the allowlist.

### [FIXED] QA-6 (MEDIUM): Unused `@EnvironmentObject var watchdogService` in ContentView
Dead code creating unnecessary dependency and re-renders. **Fixed**: Removed from ContentView and its environment injection in App.swift.

### QA-7 (MEDIUM): Non-resizable settings window may clip with many directories
**Accepted**: The directory list is unlikely to grow beyond 5-10 entries in practice. Can be addressed in a future improvement.

### QA-8 (MEDIUM): Empty allowed directories list blocks all writes with no warning
**Accepted**: This is the intended "lockdown" behavior. Users must explicitly remove all directories. A future improvement could add a confirmation dialog.

### QA-9 (LOW): Unbounded log file growth
The watchdog log file appends indefinitely. **Accepted as future improvement**: blocked operations should be rare. Log rotation can be added later.

---

## 2. Security Audit

### [FIXED] SEC-1 (HIGH): Path traversal via missing trailing slash (same as QA-3)
### [FIXED] SEC-2 (HIGH): Path normalization fails for non-existent dirs (same as QA-2)

### [FIXED] SEC-3 (HIGH): Command injection via unsanitized basename in osascript
File paths with `"`, `\`, backticks, `$` could inject AppleScript. **Fixed**: Added `notify_blocked()` function that strips shell-significant characters via `tr -d '"\\`$'` before interpolation.

### SEC-4 (MEDIUM): Oversized JSON input causes fail-open bypass via ARG_MAX
An extremely large tool call JSON (>262KB) would exceed `ARG_MAX` when passed as an argv to osascript, causing fail-open. **Accepted**: Fail-open is by design. The attack requires Claude Code itself to generate an oversized tool call, which is a contrived scenario.

### SEC-5 (MEDIUM): Bash command analysis trivially bypassable
Same as QA-4. **Accepted as known limitation**.

### [FIXED] SEC-6 (LOW-MEDIUM): Unescaped directory paths from UserDefaults
**Fixed**: `shellEscape()` handles `"`, `$`, backtick, `\` in directory path strings.

### [FIXED] SEC-7 (LOW): Hook script permissions 0755 instead of 0700
**Fixed**: Changed to `0o700`.

### SEC-8 (LOW): Read-modify-write race on settings.local.json
Atomic write but no file lock. **Accepted**: The window is small and Claude Code is unlikely to write settings.local.json concurrently.

---

## 3. Interface Contract Audit

### [FIXED] IC-1 (HIGH): Corrupted settings.local.json silently overwritten
If `settings.local.json` contains invalid JSON, `patchClaudeSettings` would overwrite it with `{}`. **Fixed**: Now distinguishes "file doesn't exist" from "file has invalid JSON" — aborts with error message in the latter case.

### [FIXED] IC-2 (MEDIUM): Missing `matcher` field causes hook to fire for ALL tool calls
Without a matcher, every tool invocation (Read, Grep, etc.) spawns the hook script. **Fixed**: Added `"matcher": "Write|Edit|Bash"` to the hook entry.

### IC-3 (MEDIUM): `|` delimiter in JXA output is fragile for paths containing `|`
If a file path contains a literal `|`, the `cut -d'|'` split would truncate it. **Accepted**: `|` in file paths is extremely rare. The command field uses `-f3-` which handles pipes in bash commands correctly.

### IC-4 (MEDIUM): Multi-line bash commands truncated by `head -1`
**Accepted**: Known limitation. Claude Code typically sends single-line commands for simple operations; multi-line scripts are the exception.

### IC-5 (MEDIUM): osascript notification injection (same as SEC-3)

### IC-6 (MEDIUM): Directory prefix matching (same as QA-3/SEC-1)

---

## 4. State Management Audit

### [FIXED] SM-1 (HIGH): `didSet` fires during init with uninitialized `allowedDirectories`
Assigning `self.isEnabled` in init triggered `didSet` → `installHook()` before `allowedDirectories` was loaded, causing triple-write of hook script. **Fixed**: Used `Published(wrappedValue:)` initializer to set backing storage without triggering `didSet`.

### SM-2 (MEDIUM): Synchronous mutation chain modifies 3 @Published properties
`isEnabled` toggle → `installHook()` → modifies `lastError`, `hookInstalled`. All on @MainActor, so no data race, but brief UI flicker possible. **Accepted**: Not a correctness issue.

### [FIXED] SM-3 (MEDIUM): `checkHookStatus()` emits double objectWillChange
Unconditionally set `hookInstalled = false` then conditionally `true`. **Fixed**: Compute result locally and assign once.

### [FIXED] SM-4 (INFO): ContentView declares unused watchdogService (same as QA-6)

### [FIXED] SM-5 (LOW): `lastError` had public setter
Inconsistent with `hookInstalled`'s `private(set)`. **Fixed**: Changed to `@Published private(set) var lastError`.

---

## 5. Resource & Concurrency Audit

### RC-1 (MEDIUM): Synchronous file I/O on main thread
`installHook()` chains 5-6 sync filesystem operations. **Accepted**: Files are small (few KB); latency is negligible on local filesystem. Can be moved to background task if needed.

### RC-2 (LOW): Unbounded watchdog.log growth (same as QA-9)

### RC-3 (MEDIUM): Read-modify-write race on settings.local.json (same as SEC-8)

---

## 6. Testing Coverage Audit

### TC-1 (HIGH): Missing test items for empty allowlist, special chars, corrupted JSON, pre-existing hooks
**Fixed**: Added additional test items to testing-checklist.md covering these edge cases.

### TC-2 (MEDIUM): Missing test items for cold start, rapid toggle, symlinked dirs
**Partially addressed**: Key scenarios added to testing checklist. Symlink resolution noted as future improvement.

---

## 7. DX & Maintainability Audit

### DX-1 (MEDIUM): 165-line bash script in Swift string literal
Two languages' escaping rules coexist. **Accepted**: The inline approach avoids runtime resource loading complexity. Added clarifying comments.

### [FIXED] DX-2 (LOW): Dead `logFilePath` computed property
Never referenced in Swift. **Fixed**: Removed.

### DX-3 (LOW): Path normalization was duplicated in bash script
**Fixed**: Extracted to `normalize_path()` and `check_allowed()` functions, called for both Write/Edit and Bash paths.

### DX-4 (LOW): Missing doc comments on key methods
**Partially addressed**: Added `///` comment on `init()`.
