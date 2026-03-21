# Audit Report: Blocked Commands (Watchdog Extension)

## Files Changed

- `Sources/ClaudeTmpMonitor/MonitorService.swift`
- `Sources/ClaudeTmpMonitor/WatchdogService.swift`
- `Sources/ClaudeTmpMonitor/SettingsView.swift`
- `Sources/ClaudeTmpMonitor/App.swift`

---

## 1. QA Audit

| # | Severity | Finding | Status |
|---|----------|---------|--------|
| 1 | Medium | Regex metacharacters in user-supplied blocked command names can break or widen the grep match | [FIXED] Input validation restricts to `[a-zA-Z0-9_-]` |
| 2 | Low | Text field clears unconditionally even on rejected (duplicate) input | Accepted — clearing signals the action was processed |
| 3 | Low | Fixed-height, non-resizable settings window will clip content with many blocked commands | [FIXED] Made settings window resizable |
| 4 | Low | No empty-state message when all blocked commands are removed | Accepted — consistent with directory list behavior |
| 5 | Info | ForEach keyed by offset rather than value (consistent with existing pattern) | Accepted — pre-existing pattern |
| 6 | Info | Blocked commands check ordering is correct (before destructive patterns) | No action needed |

## 2. Security Audit

| # | Severity | Finding | Status |
|---|----------|---------|--------|
| 1 | High | Regex metacharacters in command names cause silent bypass or false matches | [FIXED] Input validation restricts to `[a-zA-Z0-9_-]` |
| 2 | Medium | `shellEscape()` insufficient for regex context | [FIXED] Covered by input validation (no metacharacters reach the regex) |
| 3 | Medium | Missing newline/control character validation allows shell injection | [FIXED] Input validation blocks all non-`[a-zA-Z0-9_-]` characters; load-time sanitization filters stored values |
| 4 | Low | Blocked commands bypassed via absolute path (`/usr/bin/sudo`), `env`, subshell, backtick | Accepted — documented known limitation (best-effort Bash parsing) |
| 5 | Info | No memory leaks or hard crashes found | No action needed |

## 3. Interface Contract Audit

| # | Severity | Finding | Status |
|---|----------|---------|--------|
| 1 | None | UserDefaults `[String]` read/write consistency | No action needed |
| 2 | None | `Published(wrappedValue:)` init pattern correct | No action needed |
| 3 | None | Empty `BLOCKED_CMDS` bash array handled correctly | No action needed |
| 4 | Moderate | Regex metacharacter injection in grep pattern | [FIXED] Input validation |
| 5 | None | Field clearing on duplicate add | No action needed |
| 6 | None | ForEach keyed by offset (MainActor serialized) | No action needed |
| 7 | Info | Case-sensitive command matching | Accepted — consistent behavior |

## 4. State Management Audit

| # | Severity | Finding | Status |
|---|----------|---------|--------|
| 2a | Low | ForEach keyed by `.offset` instead of element value | Accepted — pre-existing pattern |
| 4b | Info | No sanitization of blockedCommands loaded from UserDefaults | [FIXED] Added load-time filtering |
| 4c | Info | Text field clears silently on duplicate command submission | Accepted |

## 5. Resource & Concurrency Audit

| # | Severity | Finding | Status |
|---|----------|---------|--------|
| 1 | None | `@MainActor` mutation safety | No action needed |
| 2 | None | `regenerateHookScript()` file write handling | No action needed |
| 3 | Low | Per-command grep fork overhead (12 forks) | Accepted — ~25-60ms total, acceptable for hook latency |
| 4 | Medium | Regex injection in blocked command names | [FIXED] Input validation |
| 5 | Low | No upper bound on blocked commands count | Accepted — impractical to exceed with manual entry via UI |
| 6 | Low | Unbounded log file growth | Pre-existing, not introduced by this change |

## 6. Testing Coverage Audit

| # | Severity | Finding | Status |
|---|----------|---------|--------|
| 1 | Medium | No test for semicolon-separated commands | [FIXED] Added checklist item |
| 2 | Low | No test for `||` operator | Covered by pipe test (regex matches `|`) |
| 3 | Low | No test for blocked command at end of line | [FIXED] Added checklist item |
| 4 | High | Regex bypass via leading whitespace (`  sudo`) | [FIXED] Changed regex to `(^\s*|[|;&]\s*)`, added checklist item |
| 5 | Medium | No test for regex metacharacters in command names | Covered by input validation fix |
| 6 | Low | No test for empty blocked commands list | [FIXED] Added checklist item |
| 7 | Medium | No test verifying check order (blocked before destructive) | Implicitly tested — blocked command fires first by design |
| 8 | Low | No test for substring in non-command context | Covered by `cat /etc/passwd` test |
| 9 | Low | No test for blocked command as argument | [FIXED] Added `echo shutdown` checklist item |
| 10 | Low | No test for modifying commands while disabled | [FIXED] Added checklist item |
| 11 | Low | No test for Enter key submission | [FIXED] Added checklist item |
| 12 | Low | No test that UI hides when watchdog is off | [FIXED] Added checklist item |

## 7. DX & Maintainability Audit

| # | Severity | Finding | Status |
|---|----------|---------|--------|
| 1.1 | Low | Duplicated list UI pattern (directories vs commands) | Accepted — extraction deferred to avoid scope creep |
| 3.3 | Low | `@State` property declared between computed properties | Accepted — natural grouping with its consumer |
| 4.1 | Low | No doc comment on `defaultBlockedCommands` rationale | [FIXED] Added doc comment |
| 4.2 | Low | Regex metacharacters in command names | [FIXED] Input validation |
| 5.1 | Info | Fixed-height non-resizable window may overflow | [FIXED] Made window resizable |
| 5.2 | Info | ForEach keyed by offset | Accepted — pre-existing pattern |
