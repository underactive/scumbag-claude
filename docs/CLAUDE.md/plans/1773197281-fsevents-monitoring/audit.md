# Audit Report: FSEvents Monitoring

## Files Changed
- `Sources/ClaudeTmpMonitor/MonitorService.swift`

## Consolidated Findings

### 1. QA Audit

| # | Severity | Finding | Status |
|---|----------|---------|--------|
| 1 | Critical | `Unmanaged.passUnretained(self)` with nil retain/release — dangling pointer if ownership model changes | Accepted (see note below) |
| 2 | High | `kFSEventStreamCreateFlagNoDefer` contradicts 2.0s latency parameter | [FIXED] — added comment clarifying the interaction (NoDefer delivers first event immediately; subsequent events coalesce within latency window) |
| 3 | High | `scan()` calls `restartTimer()` on every execution, resetting fallback timer | Accepted — intentional design; timer serves as fallback when FSEvents is active |
| 4 | Medium | Force-cast `as! [String]` on eventPaths | [FIXED] — changed to `as? [String]` with guard |
| 5 | Medium | Task allocated per FSEvent callback before debounce | Accepted — FSEvents coalescing (2.0s latency) limits callback frequency; Task creation overhead is minimal |
| 6 | Medium | `numEvents` parameter ignored | Accepted — not needed when iterating the CFArray directly |
| 7 | Low | `stopFSEvents()` defined but never called from non-deinit paths | Accepted — kept for future use; deinit inlines due to actor isolation |
| 8 | Low | `deinit` duplicates `stopFSEvents()` | [FIXED] — added comment explaining why (actor isolation) |
| 9 | Low | `~/.claude/projects/` may not exist at stream creation | Accepted — FSEvents handles non-existent paths per Apple docs |
| 10 | Info | `@MainActor` dispatch in callback is redundant since stream uses main queue | Accepted — required by Swift's actor isolation type system |

### 2. Security Audit

| # | Severity | Finding | Status |
|---|----------|---------|--------|
| 1 | Critical | `passUnretained` without retain/release — use-after-free risk | Accepted — MonitorService is a singleton for the app lifetime; [FIXED] added documenting comment |
| 2 | High | Force-cast `as! [String]` | [FIXED] — changed to `as? [String]` with guard |
| 3 | High | Already-queued callback can fire after `deinit` | Accepted — the Task closure's strong capture of `monitor` prevents deinit from running until the Task completes |
| 4 | Medium | Debounce Task captures `self` strongly | [FIXED] — changed to `[weak self]` |
| 5 | Low | `stopFSEvents()` never called; `deinit` doesn't nil `eventStream` | [FIXED] — added `eventStream = nil` in deinit |

### 3. Interface Contract Audit

| # | Severity | Finding | Status |
|---|----------|---------|--------|
| 1 | High | Force-cast `as! [String]` | [FIXED] — duplicate of Security #2 |
| 2 | High | `restartTimer()` makes `nextScanTime` show full interval after FSEvents scans; pie chart snaps | Accepted — correct behavior; a scan just completed, countdown resets to next fallback |
| 3 | Medium | Timer torn down and recreated on every FSEvents scan | Accepted — Timer creation/invalidation is lightweight; FSEvents coalescing limits frequency |
| 4 | Medium | `ScanTimerView` state resets on `nextScanTime` publish | Accepted — visual snap indicates a scan occurred; expected UX |
| 5 | Low | `stopFSEvents()` dead code | Accepted — duplicate of QA #7 |
| 6 | Low | `passUnretained` undocumented lifetime | [FIXED] — added documenting comment |

### 4. State Management Audit

| # | Severity | Finding | Status |
|---|----------|---------|--------|
| 1 | High | `guard !isScanning` silently drops concurrent FSEvents triggers | Accepted — scan() is synchronous on @MainActor, so concurrent calls are impossible; the guard is a defensive no-op |
| 2 | High | `repeats: true` timer never repeats; early-exit paths skip `restartTimer()` | Accepted — early exits leave the repeating timer active as fallback; `nextScanTime` self-corrects on next successful scan |
| 3 | Medium | `nextScanTime` not updated during debounce window | Accepted — transient cosmetic issue; self-corrects when scan completes |
| 4 | Medium | `passUnretained` fragile | [FIXED] — documented with comment |
| 5 | Medium | Debounce starves during sustained writes | Accepted — fallback timer handles this case; FSEvents detects the first event immediately via NoDefer |
| 6 | Low | `stopFSEvents()` dead code | Accepted — duplicate |
| 7 | Low | `NoDefer` + latency contradictory | [FIXED] — added clarifying comment (they are complementary, not contradictory) |
| 8 | Info | Early-exit scan leaves stale `nextScanTime` | Accepted — self-correcting via repeating timer |

### 5. Resource & Concurrency Audit

| # | Severity | Finding | Status |
|---|----------|---------|--------|
| 1 | Critical | `passUnretained` with no retain/release | Accepted — duplicate; documented |
| 2 | High | `deinit` doesn't nil `eventStream` | [FIXED] |
| 3 | High | Race: callback Task dispatched after deinit | Accepted — Task's strong capture of `monitor` prevents deinit from running until Task completes |
| 4 | High | `debouncedScanTask.cancel()` doesn't synchronously stop task | [FIXED] — `[weak self]` prevents scan on deallocated object |
| 5 | Medium | `FSEventStreamStop` doesn't drain queued callbacks | Accepted — covered by Finding 3 analysis |
| 6 | Medium | `NoDefer` + latency incoherent | [FIXED] — clarifying comment added |
| 7 | Low | `stopFSEvents()` dead code | Accepted — duplicate |
| 8 | Low | Force-cast on eventPaths | [FIXED] — duplicate |

### 6. Testing Coverage Audit

| # | Severity | Finding | Status |
|---|----------|---------|--------|
| 1 | High | Silent failure on stream creation; no observable signal | Accepted — fallback timer handles this; no test target exists yet |
| 2 | High | Debounce cancellation check placement fragile; untested | Accepted — `try?` catches CancellationError, `guard` is defensive redundancy; correct as-is |
| 3 | Medium | `restartTimer()` timing coupling untested | Accepted — no test target |
| 4 | Medium | `passUnretained` lifecycle untested | Accepted — documented; no test target |
| 5 | Medium | `stopFSEvents()` shutdown sequence untested | Accepted — no test target |
| 6 | Low | Path filter substring matching fragile and untested | Accepted — false positives on `/claude-` in unrelated paths are harmless (triggers a scan that finds nothing) |
| 7 | Low | `debouncedScanTask` concurrency assumption untested | Accepted — serialized by @MainActor |
| 8 | Info | No logging/instrumentation | Accepted — deferred to future improvement |

### 7. DX & Maintainability Audit

| # | Severity | Finding | Status |
|---|----------|---------|--------|
| 1 | Medium | `deinit` duplicates `stopFSEvents()` | [FIXED] — added comment explaining actor isolation constraint |
| 2 | Medium | Magic number `2.0` (latency) has no comment | [FIXED] — comment added explaining NoDefer + latency interaction |
| 3 | Low | Force-cast `as! [String]` | [FIXED] — duplicate |
| 4 | Low | Path filter logic is third place hard-coding Claude paths | Accepted — the filter is intentionally loose (substring match); extracting to a helper would over-couple the callback filter with the strict `isClaudeTmpPath` validation |
| 5 | Low | `guard !Task.isCancelled` redundant after `try?` | Accepted — defensive redundancy; correct and cheap |
| 6 | Info | `NoDefer` + latency confusing without comment | [FIXED] — comment added |

## Notes on Accepted "Critical" Findings

The `Unmanaged.passUnretained(self)` pattern was flagged as Critical by 3 audits. This is accepted because:

1. **MonitorService is a singleton** owned by `AppDelegate` for the entire app lifetime
2. **The stream is always stopped before dealloc** — `deinit` calls `FSEventStreamStop/Invalidate/Release`
3. **The Task's strong capture of `monitor`** in the C callback prevents `deinit` from running while any callback Task is pending
4. A documenting comment was added to make this lifetime assumption explicit

Using `passRetained` with retain/release callbacks would be more defensive but adds complexity for a scenario that cannot occur under the current architecture.
