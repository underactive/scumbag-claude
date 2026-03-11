# Audit: Growth Rate Tracking

## Files Changed
- `Sources/ClaudeTmpMonitor/MonitorService.swift`
- `Sources/ClaudeTmpMonitor/ContentView.swift`

## 1. QA Audit

1. **[FIXED] [Medium] Growth rate dilution after idle periods** — `previousSizes` unconditionally stamped `scanTime` on every scan, so if a file sat unchanged for 10 scans and then grew, the rate was diluted by the full idle duration. Fixed by carrying forward the previous timestamp when size hasn't changed.
2. [Medium] Deleted files leave stale entries in `previousSizes` until next `scan()` completes — mitigated by `scan()` being called synchronously after every deletion and the `file.size > prev.size` guard. Negligible window.
3. [Low] `formatGrowthRate` could display "0 KB/min" for very small positive rates — **[FIXED]** by adding a minimum threshold of 1 KB/min.
4. [Low] `ClaudeProject.growthRate` aggregation can cause jumpy indicators as files start/stop growing — acceptable UX tradeoff for v1.
5. [Info] No overflow risk in growth rate computation — confirmed safe.
6. [Info] `previousSizes` bounded by current file count — confirmed no unbounded growth.

## 2. Security Audit

1. **[FIXED] [Medium] UInt64 subtraction fragility** — `file.size - prev.size` relied on condition ordering to prevent underflow. Fixed by computing in Double space: `Double(file.size) - Double(prev.size)`.
2. [Low] `previousSizes` properly pruned each scan — confirmed no memory leak.
3. [Low] Double precision loss on very large UInt64 — unreachable for this domain (>9 PB).
4. **[FIXED] [Low] No `isFinite` guard on `formatGrowthRate`** — Added `bytesPerSecond.isFinite` guard.
5. [Low] Growth rate uses scan timestamps not file modification times — correct design choice, documented.
6. [Info] ContentView uses safe optional chaining — confirmed no crash risk.
7. [Info] `ClaudeProject.growthRate` handles all-nil case correctly — returns 0, filtered by UI.

## 3. Interface Contract Audit

1. [Medium] Stale `previousSizes` entries after deletion — mitigated by immediate `scan()` call and size guard. No functional bug.
2. [Medium] Growth rate nil on first scan and after interval changes — inherent to delta-based measurement. Not a bug.
3. [Low] Two-phase MonitoredFile construction — `scanDirectory` creates with `nil`, `scan()` remaps with computed rate. Fragile but functional. Deferred to future refactor.
4. [Low] Inconsistent nullability: `MonitoredFile.growthRate` is `Double?`, `ClaudeProject.growthRate` is `Double` — acceptable since `0.0` is semantically equivalent to "no growth" at the project level.
5. [Low] UInt64 subtraction safe due to guard — **[FIXED]** by using Double subtraction.
6. [Info] `formatGrowthRate` nil return consistent with UI guards — confirmed.
7. [Info] No timeout on growth rate staleness after sleep/wake — known limitation, acceptable for v1.

## 4. State Management Audit

1. [Medium] Growth rate nil on first scan — inherent one-scan-cycle latency. Not a bug.
2. **[FIXED] [Medium] `previousSizes` unconditionally overwrites timestamps** — Fixed by carrying forward timestamp when size unchanged.
3. [Low] `resolvedPath` key changes if symlink retargeted — correct behavior (different file).
4. [Low] `ClaudeProject.growthRate` re-evaluates on every access — **[FIXED]** by simplifying ContentView to call `formatGrowthRate` once (which handles the `> 0` check internally).
5. [Low] Deletion calls `scan()` which resets growth baselines — correct behavior, one-cycle gap acceptable.
6. [Info] `previousSizes` properly scoped with single-writer discipline — confirmed.
7. [Info] Pruning prevents unbounded growth — confirmed.
8. [Info] ContentView reads through standard reactive pipeline — confirmed clean data flow.

## 5. Resource & Concurrency Audit

1. [Info] `previousSizes` correctly isolated to `@MainActor` — no data race.
2. [Low] Rate spike possible with very small `timeDelta` — bounded by 0.5s debounce minimum. Self-corrects.
3. [Info] `previousSizes` properly bounded — confirmed.
4. [Low] UInt64 subtraction safe but fragile — **[FIXED]** by using Double subtraction.
5. [Info] FSEvents callback doesn't access mutable state directly — confirmed safe.
6. **[FIXED] [Low] Inconsistent formatting between `formatBytes` and `formatGrowthRate`** — Fixed by using `ByteCountFormatter` in `formatGrowthRate`.
7. [Info] No resource leaks — confirmed.
8. [Info] Computed property is safe on immutable struct — confirmed.

## 6. Testing Coverage Audit

1. [High] No automated test target exists — pre-existing project-wide gap. Not introduced by this change. Tracked in future improvements.
2. [Medium] Manual testing checklist misses edge cases (very small/large rates, file shrinkage, interval changes) — small rate issue **[FIXED]** by 1 KB/min threshold. File shrinkage correctly handled by guard. Other cases acceptable for manual testing.
3. [Medium] `formatGrowthRate` branching — **[FIXED]** by using `ByteCountFormatter`, eliminating manual branching.
4. [Low] `previousSizes` cross-scan statefulness hard to test in isolation — accepted, deferred to test target creation.
5. [Low] No snapshot/UI tests for growth rate display — accepted, project has no UI test infrastructure.
6. [Info] Manual testing checklist updated with appropriate items — confirmed.

## 7. DX & Maintainability Audit

1. **[FIXED] [Medium] Magic numbers in `formatGrowthRate`** — Replaced with `ByteCountFormatter`.
2. **[FIXED] [Medium] Inconsistent formatting approach** — Now both `formatBytes` and `formatGrowthRate` use `ByteCountFormatter`.
3. [Low] `formatGrowthRate` is a free function in MonitorService.swift — consistent with `formatBytes` pattern. Acceptable.
4. [Low] Growth rate computation rebuilds every MonitoredFile — accepted for v1, deferred to future refactor.
5. [Low] No doc comment on `previousSizes` warm-up behavior — growth rate is nil on first scan by design, self-evident from code.
6. **[FIXED] [Low] `ClaudeProject.growthRate` accessed twice** — Simplified ContentView guards since `formatGrowthRate` now handles all filtering internally.
7. [Info] No accessibility label on growth rate indicators — low priority for menubar utility.
8. [Info] `import CoreServices` confirmed not dead code — used by FSEvents.
