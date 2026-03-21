# Plan: Statistics / Historical Graphs

## Objective

Implement persistent scan history and a statistics visualization window. Users need to see how their Claude temp files grow over time to understand patterns and make informed cleanup decisions. This implements the "Statistics / historical graphs" future improvement item.

## Changes

### New Files
1. **`Sources/ClaudeTmpMonitor/HistoryService.swift`** — `@MainActor` ObservableObject with `HistorySnapshot`/`ProjectSnapshot` Codable models, two-tier aggregation (raw ≤1h, 5-minute buckets beyond), JSON persistence to `~/Library/Application Support/com.esison.claude-tmp-monitor/history.json`, configurable retention (1–30 days), 60s save timer, querying by `TimeRange` enum.
2. **`Sources/ClaudeTmpMonitor/StatsView.swift`** — Separate 600×450 resizable NSWindow with SwiftUI Charts `AreaMark`+`LineMark`, segmented time range picker (1h/24h/7d), current/peak/average summary, empty state.

### Modified Files
3. **`MonitorService.swift`** — Add `historyRetentionDays` to `SettingsKey`, add `onScanComplete` callback property, invoke it at end of `scan()`.
4. **`App.swift`** — Add `historyService` property, wire `onScanComplete` callback, add `statsWindow`, `openStats()` method, right-click menu item, `applicationWillTerminate` for flush, pass `historyService` to views.
5. **`ContentView.swift`** — Add `@EnvironmentObject var historyService`, `onOpenStats` closure, Stats button in footer.
6. **`SettingsView.swift`** — Add `@EnvironmentObject var historyService`, history retention setting row.

### Documentation
7. **`CLAUDE.md`** — Version bump, Core Files, Dependencies (Charts), new subsystem section, Settings, Data Flow, File Inventory.
8. **`Info.plist`** — Version bump to 0.4.0.
9. **`docs/CLAUDE.md/version-history.md`** — Add v0.4.0 row.
10. **`docs/CLAUDE.md/testing-checklist.md`** — Add Statistics Window section.
11. **`docs/CLAUDE.md/future-improvements.md`** — Mark item as done.

## Dependencies

- Steps 1–3 must complete before steps 4–6 (App.swift needs HistoryService to exist).
- Steps 4–6 can be parallelized.
- Step 7 (docs) is independent.

## Risks / Open Questions

| Risk | Mitigation |
|------|-----------|
| JSON file I/O on `@MainActor` | File is <500 KB; 60s save interval minimizes frequency |
| App Support directory doesn't exist on first run | `createDirectory(withIntermediateDirectories: true)` with `try?` |
| Empty chart on first launch | Empty state when <2 snapshots |
| Unbounded memory growth | Two-tier aggregation caps at ~2,256 records; pruning at each save |
