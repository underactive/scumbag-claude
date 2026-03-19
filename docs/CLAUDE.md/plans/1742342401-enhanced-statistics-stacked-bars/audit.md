# Audit Report: Enhanced Statistics with Stacked Bar Charts

## Files changed

Findings were flagged in:
- `Sources/ClaudeTmpMonitor/StatsView.swift`
- `Sources/ClaudeTmpMonitor/HistoryService.swift`

No findings in:
- `Sources/ClaudeTmpMonitor/App.swift`

---

## 1. QA Audit

### [FIXED] QA-1 (Medium): Per-project averaging divides by total bucket snapshot count
`aggregateBars` divided each project's accumulated size by the total number of snapshots in the bucket, not the number of snapshots where that project appeared. This deflated sizes for intermittent projects and was inconsistent with `HistoryService.aggregate()`. Fixed by tracking per-project appearance counts.

### [FIXED] QA-3 (Low): DateFormatter allocated on every hover event
`tooltipDateHeader()` created a new `DateFormatter` per call. Fixed with static cached formatters dictionary.

### QA-4 (Low): Tooltip positioning used hardcoded magic number 460
`tooltipOffsetX` assumed a fixed chart width. [FIXED] Replaced with computation derived from `ChartConstants.tooltipWidth`.

### [FIXED] QA-5 (Medium): Tooltip bar lookup used `Date` exact equality
Floating-point `Date` equality is fragile. Fixed by comparing truncated `timeIntervalSince1970` as `Int`.

### QA-2 (Low, accepted): `aggregateBars` produces day-level buckets for `.oneHour`
The function would produce incorrect buckets if called with `.oneHour`, but the caller branching in `body` prevents this. Added comments to unreachable switch cases for clarity.

### QA-8 (Low, accepted): Color palette wraps at 12 projects
Colors repeat via modulo for >12 projects. The legend and tooltip disambiguate by name. Acceptable design trade-off.

---

## 2. Security Audit

### [FIXED] SEC-1 (Medium): `UInt64(bytes)` in yAxisMarks could trap on extreme Double
Chart axis interpolation can produce values exceeding `UInt64.max`. Added `bytes <= Double(UInt64.max)` guard.

### SEC-3 (Low, accepted): DateFormatter allocation on hover path
Addressed — see QA-3 fix above.

### SEC-5 (Low, accepted): Unbounded snapshot growth between saves
Growth is structurally bounded by the 60s save interval and two-tier aggregation. The 30-day range queries more data but doesn't introduce unbounded growth.

---

## 3. Interface Contract Audit

### [FIXED] IC-1 (Medium): Per-project averaging inconsistency
Same as QA-1 — fixed.

### IC-7 (Medium): Tooltip magic numbers break on window resize
[FIXED] Replaced with computation from `ChartConstants.tooltipWidth`.

### IC-2 (Low, accepted): "Current" reads from unfiltered snapshots
Intentional — "Current" means "right now" regardless of selected range. Tested via new checklist item.

### IC-5 (Low, accepted): `save()` silently swallows write errors
Pre-existing behavior with explicit code comment. Non-critical subsystem.

### IC-6 (Low, accepted): 30d range always shown even when retention is 7d
The retention hint text mitigates user confusion adequately.

---

## 4. State Management Audit

### [FIXED] SM-1 (Medium): Expensive recomputation on every hover event
`hoveredBarDate` and `hoverLocation` were `@State` in `StatsView`, causing full `body` re-evaluation (including `aggregateBars` and `buildColorMap`) on every mouse move. Fixed by extracting the stacked bar chart into a child `StackedBarChartView` that owns hover state — parent only recomputes when `selectedRange` or `historyService.snapshots` changes.

### SM-5 (Low): Stale `hoveredBarDate` on range change
When switching ranges, the old hover date could persist. Now resolved structurally — hover state lives in `StackedBarChartView` which is recreated when `selectedRange` changes (SwiftUI identity resets `@State`).

### SM-2 (Low-Medium): Per-project averaging
Same as QA-1 — fixed.

### SM-6 (Low, accepted): Tuple identity collision risk
`ForEach(bar.projectSizes, id: \.name)` assumes unique display names per bar. This is a pre-existing data model concern from `extractProjectName`, not introduced by this change.

---

## 5. Resource & Concurrency Audit

No actionable findings. All state is properly `@MainActor`-isolated. Timer callbacks dispatch correctly. File I/O uses Foundation APIs that manage handles internally. `[weak self]` captures prevent retain cycles.

---

## 6. Testing Coverage Audit

### Missing checklist items addressed
Added 7 new items to `testing-checklist.md`:
- Tooltip positioning on window resize
- >12 projects color wrapping
- Sparse project presence in bars
- DST transition behavior
- Single-bar tooltip
- Current vs Peak/Average scope difference
- VoiceOver accessibility for new elements

### Noted (no automated tests exist)
- `aggregateBars` core bucketing logic
- `FlowLayout` edge cases
- `snapToBarBucket` boundary behavior
- `percentString` with zero total

These are tracked as future improvement candidates (project has no test target yet).

---

## 7. DX & Maintainability Audit

### [FIXED] DX-2/4 (Medium): Magic numbers in tooltip positioning
Replaced with `ChartConstants.tooltipWidth` and derived computation.

### [FIXED] DX-3 (Low): `minHeight: 150` duplicated
Unified via `ChartConstants.chartMinHeight`.

### [FIXED] DX-5 (Info): Unreachable `.oneHour` cases
Added clarifying comments to unreachable switch arms.

### [FIXED] DX-8 (Low): `aggregateBars` duplicates HistoryService pattern
Added doc comment explaining why Calendar-based bucketing is used instead of epoch-based.

### [FIXED] DX-9 (Medium): DateFormatter per hover
Same as QA-3 — cached.

### DX-1 (Low, accepted): `stackedBarChart` exceeded 50 lines
Resolved structurally by extracting into `StackedBarChartView`.

### DX-6 (Low, accepted): `ChartBar.id` as Date
Semantics are clear from the doc comment `// bucket start`. Renaming would add complexity for minimal gain.

### DX-7 (Low, accepted): Unnamed tuple for projectSizes
Tuple is used in a private, file-scoped context. A named struct would add ceremony without improving safety for this use case.
