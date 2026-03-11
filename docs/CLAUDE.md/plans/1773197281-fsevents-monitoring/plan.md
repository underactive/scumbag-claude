# Plan: Replace Timer Polling with FSEvents + Fallback Timer

## Objective

Replace `MonitorService`'s timer-only polling with FSEvents as the primary filesystem change detection mechanism, keeping the existing timer as a fallback. This reduces detection latency from 5–30 seconds to ~2.5 seconds worst case.

## Key Insight

Files in `/private/tmp/claude-*/` are mostly symlinks pointing to `~/.claude/projects/.../subagents/agent-*.jsonl`. Structural changes (new symlinks) happen in `/private/tmp/`, but file size growth happens at the symlink targets in `~/.claude/projects/`. Both paths must be watched.

## Changes

### `Sources/ClaudeTmpMonitor/MonitorService.swift`
- Add `import CoreServices`
- Add `eventStream: FSEventStreamRef?` and `debouncedScanTask: Task<Void, Never>?` properties
- Add `startFSEvents()`: watches `/private/tmp` and `~/.claude/projects/`, filters for relevant paths, debounces via `scheduleDebouncedScan()`
- Add `stopFSEvents()`: stops, invalidates, and releases the stream
- Add `scheduleDebouncedScan()`: 0.5s debounce coalescer
- Modify `init()`: call `startFSEvents()` after `startTimer()`
- Modify `deinit`: inline FSEvents cleanup (to avoid actor isolation error), cancel debounce task
- Modify `scan()`: call `restartTimer()` at end to reset fallback countdown after every scan

### `CLAUDE.md`
- Remove "No FSEvents" from Known Issues
- Update File Monitoring section to document FSEvents primary + timer fallback
- Add CoreServices to Dependencies

### `docs/CLAUDE.md/future-improvements.md`
- Mark FSEvents item as done `[x]`

## Design Decisions

1. Watch `/private/tmp` (parent) because `claude-*` dirs may not exist at startup
2. Watch `~/.claude/projects/` to catch symlink target file growth
3. Keep timer as fallback safety net (default 15s)
4. Restart timer after every scan so pie chart is always accurate
5. 0.5s debounce + 2s FSEvents latency = ~2.5s worst-case detection
6. Filter in callback to avoid scanning on unrelated `/private/tmp/` activity
7. Use `FSEventStreamSetDispatchQueue` (not deprecated `FSEventStreamScheduleWithRunLoop`)

## Risks

1. `/private/tmp/` noise — mitigated by path filtering in callback
2. `@MainActor` + C callback — standard `Unmanaged` + `Task { @MainActor }` pattern
3. `deinit` actor isolation — inline FSEvents cleanup directly instead of calling `stopFSEvents()`
