# Implementation: FSEvents Monitoring

## Files Changed
- `Sources/ClaudeTmpMonitor/MonitorService.swift` — Added FSEvents integration (CoreServices import, stream lifecycle, debounced scan, timer reset)
- `CLAUDE.md` — Updated Dependencies, File Monitoring docs, removed "No FSEvents" known issue, renumbered remaining items
- `docs/CLAUDE.md/future-improvements.md` — Marked FSEvents item as done

## Summary

Implemented FSEvents as primary filesystem change detection with timer fallback, matching the plan exactly. Key implementation details:

- **FSEventStream** watches `/private/tmp` and `~/.claude/projects/` with 2.0s latency and `kFSEventStreamCreateFlagNoDefer`
- **Callback** filters event paths for `/claude-` or `/.claude/projects/` before scheduling a scan
- **Debounce** via `scheduleDebouncedScan()` coalesces rapid callbacks with 0.5s delay
- **Timer reset** after every `scan()` call keeps the pie chart countdown accurate
- Used `FSEventStreamSetDispatchQueue` instead of deprecated `FSEventStreamScheduleWithRunLoop`
- Inlined FSEvents cleanup in `deinit` to avoid `@MainActor` isolation error (can't call actor-isolated methods from nonisolated `deinit`)

## Verification
- `swift build -c release` — compiles with no errors or warnings
- `make bundle` — app bundle builds successfully

## Follow-ups
- Manual testing needed: create/delete files in `/private/tmp/claude-test/` and verify ~3s detection
- Verify pie chart timer resets correctly after FSEvents-triggered scans

## Audit Fixes

### Fixes applied
1. **Safe cast on eventPaths** — Changed `as! [String]` to `guard let ... as? [String] else { return }` (Security #2, QA #4, Interface #1, DX #3)
2. **`[weak self]` in debounce task** — Prevents strong capture of MonitorService in debounce Task closure (Security #4, Resource #4)
3. **`eventStream = nil` in deinit** — Added nil-out after FSEventStreamRelease for consistency with `stopFSEvents()` (Resource #2, Security #5)
4. **Comment: `passUnretained` lifetime safety** — Documents why unretained is safe (singleton owned by AppDelegate) (Security #1, Interface #6, State #4)
5. **Comment: NoDefer + latency interaction** — Clarifies that NoDefer delivers first event immediately while subsequent events coalesce within latency window (QA #2, DX #2, DX #6, State #7, Resource #6)
6. **Comment: deinit inlining reason** — Documents actor isolation constraint preventing `stopFSEvents()` call (DX #1)

### Verification checklist
- [x] `swift build -c release` — compiles with no errors or warnings after all fixes
- [ ] Verify safe cast doesn't drop events in practice (FSEvents always delivers CFString with UseCFTypes flag)
- [ ] Verify `[weak self]` doesn't cause missed scans during normal operation
- [ ] Verify `eventStream = nil` in deinit doesn't cause issues (harmless — object is being deallocated)
