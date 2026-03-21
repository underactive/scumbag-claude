# Implementation: Growth Rate Tracking

## Files Changed
- `Sources/ClaudeTmpMonitor/MonitorService.swift` — Added `growthRate` field to `MonitoredFile`, computed `growthRate` property to `ClaudeProject`, `previousSizes` state tracking, growth rate computation in `scan()`, `formatGrowthRate()` free function
- `Sources/ClaudeTmpMonitor/ContentView.swift` — Added "↑ X.X MB/min" indicators to project rows and file rows
- `CLAUDE.md` — Updated MonitorService description, added growth rate tracking docs to File Monitoring subsection, bumped version
- `Info.plist` — Bumped version to 0.3.5
- `docs/CLAUDE.md/future-improvements.md` — Marked growth rate tracking as done
- `docs/CLAUDE.md/version-history.md` — Added v0.3.5 entry
- `docs/CLAUDE.md/testing-checklist.md` — Added Growth Rate Tracking section with 6 test items

## Summary

Implemented growth rate tracking as specified in the plan. Key details:

- **Model**: Added `growthRate: Double?` to `MonitoredFile` (bytes/sec, nil when no prior data or not growing). Added `growthRate: Double` computed property to `ClaudeProject` (sum of file growth rates via `compactMap`/`reduce`).
- **State**: Added `previousSizes: [String: (size: UInt64, time: Date)]` dictionary keyed by resolved path. Ephemeral runtime state, not persisted.
- **Scan logic**: Captures `scanTime = Date()` at start. After `scanDirectory` returns raw files, maps over them to compute growth rates by comparing to `previousSizes`. Rebuilds `previousSizes` from current scan results (implicitly prunes stale entries).
- **Formatter**: `formatGrowthRate(_ bytesPerSecond: Double) -> String?` converts to per-minute display with appropriate unit (KB/min, MB/min, GB/min). Returns nil for non-positive rates.
- **UI**: Project rows show "↑ X.X MB/min" in orange `.caption.monospacedDigit()` after the size text. File rows show the same in `.caption2.monospacedDigit()`. Only visible when growth rate > 0.

No deviations from the plan.

## Verification
- `swift build -c release` — compiles with no errors or warnings

## Follow-ups
- Manual testing needed: create a growing file in `/private/tmp/claude-test/` and verify indicator appears after second scan
- First scan correctly shows nil (no indicators) since no prior data exists

## Audit Fixes

### Fixes applied
1. **Carry forward timestamps for unchanged files** — `previousSizes` rebuild now preserves the previous timestamp when file size hasn't changed, preventing growth rate dilution after idle periods (QA #1, State #2)
2. **Double-space subtraction** — Changed `Double(file.size - prev.size)` to `Double(file.size) - Double(prev.size)` to eliminate fragile dependency on UInt64 subtraction ordering (Security #1, Interface #5, Resource #4)
3. **`isFinite` guard in `formatGrowthRate`** — Added `bytesPerSecond.isFinite` check to handle corrupted/NaN inputs (Security #4)
4. **`ByteCountFormatter` in `formatGrowthRate`** — Replaced manual magic-number thresholds with `ByteCountFormatter.string(fromByteCount:countStyle:)` for consistency with `formatBytes()` (DX #1, DX #2, Resource #6)
5. **Minimum rate threshold** — Added 1 KB/min floor to suppress "0 KB/min" display for negligible growth rates (QA #3, Testing #2)
6. **Simplified ContentView guards** — Removed redundant `> 0` checks since `formatGrowthRate` handles all filtering internally, avoiding double computation of `ClaudeProject.growthRate` (DX #6, State #4)

### Verification checklist
- [x] `swift build -c release` — compiles with no errors or warnings after all fixes
- [ ] Verify growth rate displays correctly after a file stops growing and resumes (fix #1)
- [ ] Verify growth rate shows nil for corrupted/NaN inputs (fix #3)
- [ ] Verify `ByteCountFormatter` output matches expected format with "/min" suffix (fix #4)
- [ ] Verify sub-1 KB/min growth rates are suppressed (fix #5)
