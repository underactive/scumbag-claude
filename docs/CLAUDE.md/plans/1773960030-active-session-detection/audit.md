# Audit: Active Session Detection

## Files Changed

Findings were flagged in these files:
- `Sources/ClaudeTmpMonitor/MonitorService.swift`
- `Sources/ClaudeTmpMonitor/ContentView.swift`
- `docs/CLAUDE.md/testing-checklist.md`

No findings in immediate dependents (`HistoryService.swift`, `StatsView.swift`, `App.swift`).

---

## 1. QA Audit

| # | Severity | Location | Finding | Status |
|---|----------|----------|---------|--------|
| QA-1 | Low | MonitorService.swift:540 | `growthRate! > 0` force-unwrap after nil check is always true for non-nil values; misleading dead condition | [FIXED] |
| QA-2 | Info | MonitorService.swift:539 | `lastMod` reflects target mtime for symlinks; external writes can trigger false "live" | Accepted — by design; file recency is the intended signal |
| QA-3 | N/A | MonitorService.swift:566-593 | Dedup rebuild correctly carries `isActive` | Confirmed correct |
| QA-4 | Design | MonitorService.swift:162 | 60s threshold is undocumented and unexposed; hysteresis could confuse users | [FIXED] — added inline comment |
| QA-5 | Low | MonitorService.swift + ContentView.swift | `isStale` and `isActive` have no mutual exclusion; both badges could co-render | [FIXED] |
| QA-6 | Info | ContentView.swift:122-133 | `repeatForever` animation runs per active row; acceptable at current scale | Accepted |
| QA-7 | N/A | ContentView.swift:131-132 | No `onDisappear` needed for correctness | [FIXED] — added anyway as best practice |
| QA-8 | Low | ContentView.swift:361-382 | No `else if` guard between stale and active rendering | [FIXED] — added `&& !project.isActive` |
| QA-9 | Low | ContentView.swift:127 | Hardcoded `Color.green` has no accessibility contrast guarantee | Accepted — matches existing badge patterns in the codebase |

## 2. Security Audit

No security vulnerabilities found. All new code is purely internal — no unsanitized external input, no overflow risk, no resource leaks, no injection vectors.

## 3. Interface Contract Audit

| # | Severity | Location | Finding | Status |
|---|----------|----------|---------|--------|
| IC-1 | N/A | MonitorService.swift:566-593 | Dedup rebuild correctly carries `isActive` | Confirmed correct |
| IC-2 | N/A | HistoryService.swift | `isActive` intentionally not persisted in `ProjectSnapshot` | Confirmed correct |
| IC-3 | Low | MonitorService.swift + ContentView.swift | `isStale` and `isActive` can both be true simultaneously | [FIXED] — UI now shows `isActive` taking priority |
| IC-4 | Cosmetic | MonitorService.swift:540 | Force-unwrap `$0.growthRate!` safe but fragile | [FIXED] — replaced with `?? 0` |
| IC-5 | N/A | MonitorService.swift:539 | `scanTime` used consistently for both `isStale` and `isActive` | Confirmed correct |
| IC-6 | Info | MonitorService.swift:539 | `isActive` reflects symlink target mtime, not symlink ctime | Accepted — correct behavior |
| IC-7 | N/A | ContentView.swift | `PulsingDot` lifecycle handles view reuse correctly | Confirmed correct |

## 4. State Management Audit

| # | Severity | Location | Finding | Status |
|---|----------|----------|---------|--------|
| SM-1 | Low | MonitorService.swift:539 | `isActive` uses target mtime for symlinked projects | Accepted — by design |
| SM-2 | N/A | MonitorService.swift:590 | Dedup rebuild carry-through is correct | Confirmed correct |
| SM-3 | Low | MonitorService.swift:539-626 | Fragile ordering: `isActive` must be computed before `previousSizes` is overwritten | Accepted — ordering is correct; added sync comment on dedup block |
| SM-4 | N/A | ContentView.swift:122-133 | `PulsingDot` @State lifecycle is correct | Confirmed correct |
| SM-5 | Medium | ContentView.swift:361-382 | Simultaneous "stale" + "live" badges are contradictory | [FIXED] |

## 5. Resource & Concurrency Audit

| # | Severity | Location | Finding | Status |
|---|----------|----------|---------|--------|
| RC-1 | Low | ContentView.swift:131 | `repeatForever` animation should have `.onDisappear` for clean teardown | [FIXED] |
| RC-2 | Info | MonitorService.swift:539 | `isActive` based on mtime may lag for open file descriptors; growth-rate fallback mitigates | Accepted |
| RC-3 | N/A | MonitorService.swift:591 | Dedup carry-through is correct | Confirmed correct |
| RC-4 | N/A | MonitorService.swift:476-638 | No data races; @MainActor isolation covers all shared state | Confirmed correct |

## 6. Testing Coverage Audit

| # | Severity | Finding | Status |
|---|----------|---------|--------|
| TC-1 | Medium | No test for stale+live co-appearance edge case | [FIXED] — added checklist item |
| TC-2 | Low | No test for `isActive` through dedup rebuild path | [FIXED] — added checklist item |
| TC-3 | Low | No test for live badge appearing immediately on popover open | [FIXED] — added checklist item |
| TC-4 | Low | 60-second threshold test ambiguous without "after next scan" qualifier | [FIXED] — updated checklist item wording |
| TC-5 | Medium | Growth rate condition for `isActive` undertested | [FIXED] — added checklist item |
| TC-6 | Low | No test for badge disappearing after growth stops | [FIXED] — added checklist item |

## 7. DX & Maintainability Audit

| # | Severity | Location | Finding | Status |
|---|----------|----------|---------|--------|
| DX-1 | Low | MonitorService.swift:540 | Force-unwrap after nil check | [FIXED] |
| DX-2 | Low | MonitorService.swift:566-593 | Dual init sites with no sync comment | [FIXED] — added comment |
| DX-3 | Low | MonitorService.swift:162 | Missing unit/rationale comment on `activeSessionThreshold` | [FIXED] |
| DX-4 | Low | MonitorService.swift:50-51 | Missing doc comment on `isActive` field | [FIXED] |
| DX-5 | Low | ContentView.swift:127 | Hardcoded color prevents reuse | Accepted — single use case; parameterizing is premature |
| DX-6 | Info | ContentView.swift:370-382 | Undocumented layout asymmetry between badges | Accepted — layout is visually correct |
| DX-7 | Info | ContentView.swift:381 | "stale" badge has no tooltip | Accepted — pre-existing pattern; not in scope |
| DX-8 | Low | CLAUDE.md | `isActive` not documented | Already addressed — CLAUDE.md was updated as part of implementation |
