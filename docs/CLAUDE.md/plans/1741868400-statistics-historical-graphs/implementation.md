# Implementation: Statistics / Historical Graphs

## Files Changed

### Created
- `Sources/ClaudeTmpMonitor/HistoryService.swift` — New service: data models, persistence, aggregation, querying
- `Sources/ClaudeTmpMonitor/StatsView.swift` — New view: SwiftUI Charts statistics window

### Modified
- `Sources/ClaudeTmpMonitor/MonitorService.swift` — Added `SettingsKey.historyRetentionDays`, `onScanComplete` callback property, callback invocation at end of `scan()`
- `Sources/ClaudeTmpMonitor/App.swift` — Added `historyService` property, `statsWindow`, `openStats()`, wired `onScanComplete` callback, `applicationWillTerminate`, updated right-click menu, passed `historyService` to views
- `Sources/ClaudeTmpMonitor/ContentView.swift` — Added `historyService` environment object, `onOpenStats` closure, Stats button in footer
- `Sources/ClaudeTmpMonitor/SettingsView.swift` — Added `historyService` environment object, history retention setting row
- `Sources/ClaudeTmpMonitor/CLAUDE.md` — Version bump to 0.4.0, updated Core Files (6→8), Dependencies (+Charts), new subsystem §2, Settings (+historyRetentionDays), Data Flow, File Inventory
- `Info.plist` — Version bump to 0.4.0
- `docs/CLAUDE.md/version-history.md` — Added v0.4.0 row
- `docs/CLAUDE.md/testing-checklist.md` — Added Statistics Window section (17 test items)
- `docs/CLAUDE.md/future-improvements.md` — Marked "Statistics / historical graphs" as done

## Summary

Implemented exactly as planned. No deviations. Key architectural decisions:
- `HistoryService` follows the same `@MainActor ObservableObject` pattern as `MonitorService` and `UpdateService`
- Coupling between MonitorService and HistoryService is a single closure callback (`onScanComplete`), wired in AppDelegate
- Two-tier aggregation: raw snapshots for ≤1 hour, 5-minute averaged buckets beyond, with configurable retention pruning
- SwiftUI Charts with `AreaMark` (gradient fill) + `LineMark` (stroke) for visual appeal
- Empty state shown when <2 data points

## Verification

- [ ] `make build` succeeds with no warnings from new code (blocked by sandbox — user must verify)
- [ ] `make bundle` and launch — Stats button in footer, Statistics in right-click menu
- [ ] Wait 2+ minutes, open Statistics — chart populates
- [ ] Switch time ranges — chart and summary stats update
- [ ] Quit and relaunch — history.json persists, chart shows prior data
- [ ] Change retention in Settings — value persists
- [ ] Delete history.json, relaunch — empty state appears

## Follow-ups

- Per-project chart breakdown (data is stored but only totalSize charted in v1)
- Move JSON I/O to background queue if file size becomes a concern
- Consider SQLite if data volume grows significantly

## Audit Fixes

### Fixes applied

1. **[S4/I4] Guard negative Double in chart Y-axis label** — Added `bytes >= 0` check before `UInt64(bytes)` cast in StatsView Y-axis `AxisValueLabel` to prevent runtime trap when Charts auto-scales below zero.
2. **[S9/Q8/I6] Use `max(by:)` for current size and sort `snapshots(for:)`** — Changed `snapshots.last` to `snapshots.max(by: { $0.timestamp < $1.timestamp })` for the "Current" stat. Added `.sorted { $0.timestamp < $1.timestamp }` to `snapshots(for:)` to guarantee chronological order for chart rendering.
3. **[SM1/Q4/I3] Eliminate intermediate mutation in `save()`** — Refactored `save()` to compute the compacted snapshots array entirely in local `let` variables, with a single atomic assignment to `self.snapshots` at the end. Also encodes the local `compacted` array (not `self.snapshots`) to prevent disk/memory divergence on encode failure.
4. **[SM4/Q7] Single-pass filter in StatsView** — Changed `peakSize(in:)` and `averageSize(in:)` to accept a pre-filtered `[HistorySnapshot]` array instead of a `TimeRange`, eliminating 2 redundant O(n) filter passes per render.
5. **[Q9/D11] Bump settings window height** — Increased from 300pt to 330pt to accommodate the new "History retention" row.
6. **[Q10] Add chart minimum height** — Added `.frame(minHeight: 150)` to the Chart to prevent collapse at small window sizes.
7. **[D1] Document didSet re-entry pattern** — Added comment explaining the recursive `didSet` clamp behavior on `historyRetentionDays`.
8. **[D2] Document aggregate() algorithm** — Added doc comment explaining bucketing, averaging, and median timestamp selection.
9. **[D3/D4] Symbolic save timer constant** — Extracted `saveIntervalSeconds = 60` as a static constant; computed tolerance as `saveIntervalSeconds * 0.1` to match MonitorService pattern.
10. **[D5] Document onScanComplete contract** — Added doc comment specifying threading, timing, and re-entrancy constraints.
11. **[D6] Comment chart minimum data points** — Added comment explaining Swift Charts requires ≥ 2 data points for LineMark/AreaMark.

### Verification checklist

- [ ] Chart renders correctly when Y-axis range includes values near zero (no crash)
- [ ] "Current" stat shows the most recent snapshot's value, not a stale older value
- [ ] Chart line is smooth (no zigzag from unsorted data) across all time ranges
- [ ] Settings window fully displays all rows including "History retention" without clipping
- [ ] Chart does not collapse to zero height when Statistics window is resized small
- [ ] Statistics view doesn't cause visible UI lag with 7+ days of accumulated data

### Unresolved items

See the "Deferred Findings" section in `audit.md` for findings intentionally not fixed with rationale.
