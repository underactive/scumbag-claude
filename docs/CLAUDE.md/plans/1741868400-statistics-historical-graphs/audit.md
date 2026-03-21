# Audit Report: Statistics / Historical Graphs

## Files Changed

Files where findings were flagged (including immediate dependents):

- `Sources/ClaudeTmpMonitor/HistoryService.swift`
- `Sources/ClaudeTmpMonitor/StatsView.swift`
- `Sources/ClaudeTmpMonitor/MonitorService.swift`
- `Sources/ClaudeTmpMonitor/App.swift`
- `Sources/ClaudeTmpMonitor/ContentView.swift`
- `Sources/ClaudeTmpMonitor/SettingsView.swift`

---

## 1. QA Audit

| # | File | Severity | Finding |
|---|------|----------|---------|
| Q1 | HistoryService.swift | Medium | Unbounded snapshot accumulation between 60s save ticks |
| Q2 | HistoryService.swift | Medium | Integer division truncates fractional averages in `aggregate()` |
| Q3 | HistoryService.swift | Medium | UInt64 overflow in `averageSize` reduce accumulator |
| Q4 | HistoryService.swift | Medium | `save()` mutates `snapshots` in-place through intermediate states |
| Q5 | HistoryService.swift | Medium | Midpoint timestamp uses array index of unsorted group |
| Q6 | HistoryService.swift | Low | `createDirectory` failure silently disables persistence |
| [FIXED] Q7 | StatsView.swift | Medium | Triple O(n) filter passes per body render — `peakSize`/`averageSize` re-filter |
| [FIXED] Q8 | StatsView.swift | Low | `snapshots.last` may not be most-recent after aggregation reorder |
| [FIXED] Q9 | App.swift | Low | Settings window height (300pt) may clip new "History retention" row |
| [FIXED] Q10 | StatsView.swift | Low | No minimum height on chart — collapses at small window sizes |
| Q11 | App.swift | Low | `onScanComplete` assigned after `init()` posts initial scan (timing dependency) |
| Q12 | MonitorService.swift | Low | `onScanComplete` called while `isScanning = true` (deferred via defer) |

---

## 2. Security Audit

| # | File | Severity | Finding |
|---|------|----------|---------|
| S1 | HistoryService.swift | Medium | Unbounded in-memory snapshot growth between saves |
| S2 | HistoryService.swift | Medium | UInt64 overflow in `averageSize` accumulator |
| S3 | HistoryService.swift | Medium | UInt64 overflow in `aggregate()` project size accumulator |
| [FIXED] S4 | StatsView.swift | Medium | `UInt64(bytes)` traps on negative Double from Charts Y-axis |
| S5 | StatsView.swift | Medium | `Double(snapshot.totalSize)` loses precision above ~9 PB |
| S6 | HistoryService.swift | Low | `id: Date` collision-prone for `Identifiable` |
| S7 | HistoryService.swift | Low | `deinit` does not flush pending snapshots |
| S8 | HistoryService.swift | Low | Persistence errors silently swallowed |
| [FIXED] S9 | StatsView.swift | Low | `snapshots.last` may not be most-recent after aggregation |
| S10 | MonitorService.swift | Low | `onScanComplete` closure pattern requires `[weak self]` but is undocumented |

---

## 3. Interface Contract Audit

| # | File | Severity | Finding |
|---|------|----------|---------|
| I1 | HistoryService.swift | Medium | `@Published didSet` clamp emits extraneous `objectWillChange` for out-of-range values |
| I2 | HistoryService.swift | Medium | UInt64 overflow in `averageSize` accumulation |
| I3 | HistoryService.swift | Medium | `snapshots` mutated in-place before write; disk diverges from memory on encode failure |
| [FIXED] I4 | StatsView.swift | Medium | `UInt64(bytes)` traps on negative Y-axis grid-line values |
| I5 | StatsView.swift | Medium | "Current" size reads from history tail instead of live `MonitorService.totalSize` |
| [FIXED] I6 | StatsView.swift | Low | Chart data may be partially unsorted, causing visual zigzag artifacts |
| I7 | HistoryService.swift | Low | No schema versioning for JSON persistence |
| I8 | HistoryService.swift | Low | `createDirectory` failure silently disables persistence |
| I9 | MonitorService.swift | Low | First-scan history recording depends on unguarded task-ordering assumption |

---

## 4. State Management Audit

| # | File | Severity | Finding |
|---|------|----------|---------|
| [FIXED] SM1 | HistoryService.swift | Critical | `save()` mutates `snapshots` as hidden side effect — intermediate states visible |
| SM2 | HistoryService.swift | Critical | `didSet` recursively re-assigns `historyRetentionDays` (fragile, not infinite) |
| SM3 | HistoryService.swift | Medium | Redundant `Task { @MainActor }` in timer closure (required by Swift type system) |
| [FIXED] SM4 | StatsView.swift | Medium | Three independent O(n) filter passes per body render |
| SM5 | StatsView.swift | Low | `currentSize` from `snapshots.last` shadows canonical `MonitorService.totalSize` |
| SM6 | App.swift | Medium | `onScanComplete` wired after `init()` schedules initial scan |
| SM7 | MonitorService.swift | Medium | `onScanComplete` closure contract undocumented |

---

## 5. Resource & Concurrency Audit

| # | File | Severity | Finding |
|---|------|----------|---------|
| R1 | HistoryService.swift | Medium | `deinit` invalidates Timer from nonisolated context — potential race |
| R2 | HistoryService.swift | Medium | `aggregate()` is O(n × projects) per bucket, called on main thread |
| R3 | HistoryService.swift | Low | Save timer uses `.default` run loop mode; should use `.common` |
| R4 | MonitorService.swift | Low | `onScanComplete` has no explicit actor annotation |
| R5 | MonitorService.swift | Low | `deinit` accesses actor-isolated properties without isolation |

---

## 6. Testing Coverage Audit

| # | File | Severity | Finding |
|---|------|----------|---------|
| T1 | HistoryService.swift | Medium | `aggregate()` edge cases have no checklist coverage |
| T2 | HistoryService.swift | Medium | Save failure behavior has no checklist coverage |
| T3 | HistoryService.swift | Medium | Snapshot accumulation / memory stability not in checklist |
| T4 | StatsView.swift | Medium | "Current" vs range consistency not in checklist |
| T5 | testing-checklist.md | Medium | Missing items: aggregation, retention pruning timing, accessibility |

---

## 7. DX & Maintainability Audit

| # | File | Severity | Finding |
|---|------|----------|---------|
| [FIXED] D1 | HistoryService.swift | Medium | `didSet` re-entry pattern lacks a `// WHY:` comment |
| [FIXED] D2 | HistoryService.swift | Medium | `aggregate()` has no function-level doc comment |
| [FIXED] D3 | HistoryService.swift | Low | Magic number `60` (save timer) — no symbolic constant |
| [FIXED] D4 | HistoryService.swift | Low | Magic number `6` (timer tolerance) — inconsistent with MonitorService pattern |
| [FIXED] D5 | MonitorService.swift | Low | `onScanComplete` undocumented — threading, timing, re-entrancy constraints |
| [FIXED] D6 | StatsView.swift | Low | Magic number `2` for minimum chart data points — no comment |
| D7 | StatsView.swift | Low | `xAxisFormat` has duplicate cases for `.oneHour` and `.twentyFourHours` |
| D8 | HistoryService.swift | Low | `saveNow()` trivial wrapper with no doc comment |
| D9 | HistoryService.swift | Low | Silent `catch` block cites Dev Rule 6 but doesn't fully explain rationale |
| D10 | App.swift | Low | `openStats()` is `@objc` but `openSettings()` is not — unexplained asymmetry |
| [FIXED] D11 | SettingsView.swift/App.swift | Low | New row added but settings window height not updated |

---

## Cross-Audit Summary: Deferred Findings

The following findings were intentionally not fixed because they are either pre-existing patterns, physically unreachable conditions, or acceptable trade-offs:

- **UInt64 overflow in averages/sums** (Q3, S2, S3, I2): Would require >18 exabytes of cumulative data — physically impossible with real filesystem sizes.
- **Double precision loss above 9 PB** (S5): Not reachable with real monitored files.
- **`id: Date` collision** (S6): Sub-second Date resolution makes collision extremely unlikely. Adding UUID would change the Codable schema.
- **`didSet` recursive re-assignment** (SM2, I1): Pre-existing pattern from MonitorService. Fragile but terminates correctly. A broader refactor to use a setter method would be needed to fix all instances.
- **`deinit` nonisolated timer access** (R1, R5): Pre-existing pattern from MonitorService. Both services are singletons for the app lifetime; `deinit` is only called during process exit.
- **Timer `.default` run loop mode** (R3): Menubar app has no modal sheets or panels that would suppress `.default` mode timers.
- **"Current" stat from history vs live MonitorService** (I5, SM5): Intentional — StatsView only depends on HistoryService. The value lags by at most one scan interval (~15s), which is acceptable for a statistics display.
- **First scan ordering assumption** (Q11, SM6, I9): Safe today because `Task {}` in `init()` always yields until after `applicationDidFinishLaunching` completes. Would need to be revisited if init ever calls `scan()` synchronously.
- **Aggregate integer division truncation** (Q2): Integer averaging is standard for this domain. Sub-byte precision is meaningless for file size statistics.
- **Missing testing checklist items** (T1–T5): Addressed separately below.
