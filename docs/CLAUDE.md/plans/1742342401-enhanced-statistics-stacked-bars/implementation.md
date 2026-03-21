# Implementation: Enhanced Statistics with Stacked Bar Charts

## Files changed

- `Sources/ClaudeTmpMonitor/HistoryService.swift` — added `.thirtyDays` case to `TimeRange` enum
- `Sources/ClaudeTmpMonitor/StatsView.swift` — major rewrite: dual chart rendering, stacked bar charts, hover tooltips, color legend, flow layout, retention hint
- `Sources/ClaudeTmpMonitor/App.swift` — bumped stats window content size from 600×450 to 700×550
- `Info.plist` — version bump 0.4.2 → 0.5.0
- `CLAUDE.md` — updated version, StatsView description, History & Statistics subsection, Charts dependency
- `docs/CLAUDE.md/version-history.md` — added v0.5.0 row
- `docs/CLAUDE.md/testing-checklist.md` — added 24 test items for bar charts, tooltips, 30d range, retention hint, legend, window size, edge cases

## Summary

Implemented exactly as planned with no deviations:

1. **HistoryService**: Added `.thirtyDays = "30d"` case returning 2,592,000 seconds.

2. **StatsView** (complete rewrite, ~350 lines):
   - `ChartBar` model with `id: Date` (bucket start) and `projectSizes` array
   - `aggregateBars(from:range:)` groups snapshots into calendar-aligned buckets (`.hour` for 24h, `.day` for 7d/30d) and averages per-project sizes
   - 12-color palette with deterministic assignment by sorted project name index
   - Dual rendering: area+line for 1h, stacked `BarMark` with `foregroundStyle(by:)` for other ranges
   - Hover tooltip via `.chartOverlay` + `.onContinuousHover`, snaps to bar bucket, shows date header + total + per-project rows sorted by size descending with color dot, name, size, percentage
   - `FlowLayout` custom `Layout` for wrapping legend
   - Retention hint when 30d selected and retention < 30

3. **App.swift**: Stats window 700×550.

4. **Documentation**: All files updated per plan.

## Verification

- `swift build` — clean debug build (7.92s)
- `make build` — clean release build (5.37s)
- No compiler warnings or errors
- All `switch` statements on `TimeRange` handle the new `.thirtyDays` case

## Audit Fixes

### Fixes applied

1. **SEC-1 / yAxisMarks UInt64 overflow guard** — Added `bytes <= Double(UInt64.max)` condition to prevent runtime trap on extreme chart axis interpolated values.
2. **QA-1 / IC-1 / SM-2 / Per-project averaging** — Changed `aggregateBars` to track per-project appearance counts and divide by them (instead of total bucket snapshot count), consistent with `HistoryService.aggregate()`.
3. **QA-3 / DX-9 / SM-3 / DateFormatter caching** — Replaced per-call `DateFormatter` allocation in `tooltipDateHeader` with static cached formatters dictionary.
4. **QA-5 / Date equality fragility** — Replaced `$0.id == hoveredDate` with `Int($0.id.timeIntervalSince1970) == Int(hoveredDate.timeIntervalSince1970)` for robust bucket matching.
5. **SM-1 / Hover recomputation** — Extracted stacked bar chart into `StackedBarChartView` child view that owns `hoveredBarDate`/`hoverLocation` state, preventing `aggregateBars`/`buildColorMap` recomputation on every mouse move.
6. **SM-5 / Stale hover state** — Resolved structurally by fix #5: `StackedBarChartView`'s `@State` resets when SwiftUI recreates the view on range change.
7. **DX-2/4 / IC-7 / QA-4 / Magic numbers** — Introduced `ChartConstants` enum with `tooltipWidth`, `chartMinHeight`, `pickerWidth`, and `palette`. Tooltip offset computation derives from `tooltipWidth`.
8. **DX-5 / Unreachable switch arms** — Added clarifying comments to `.oneHour` cases in `xAxisFormat`, `barCalendarUnit`, and `snapToBarBucket`.
9. **DX-8 / aggregateBars comment** — Added doc comment explaining why Calendar-based bucketing is used instead of reusing `HistoryService.aggregate`.
10. **Testing M1-M7 / Missing checklist items** — Added 7 additional test items covering tooltip resize, >12 projects, sparse presence, DST, single bar, Current scope, VoiceOver.

### Verification checklist

- [x] Build clean (debug + release, zero warnings)
- [ ] Verify per-project averaging produces correct bar heights when a project appears in only some snapshots within a bucket
- [ ] Verify tooltip appears reliably after hover on all bar ranges (no floating-point mismatch)
- [ ] Verify hover over bars does not cause visible lag (child view isolation working)
- [ ] Verify tooltip position adapts when resizing the stats window
- [ ] Verify unreachable `.oneHour` cases don't execute (1h shows area chart, not bars)

### Unresolved items (accepted as-is)

- **QA-8**: Color palette wraps at 12 projects — acceptable, legend disambiguates by name
- **IC-2**: "Current" reads from unfiltered snapshots — intentional design
- **IC-5**: `save()` silently swallows errors — pre-existing, non-critical
- **IC-6**: 30d range always shown — retention hint mitigates
- **SM-6**: Tuple identity collision on duplicate display names — pre-existing data model concern
- **DX-6/7**: `ChartBar.id` naming, unnamed tuple — acceptable for private, file-scoped types

## Follow-ups

- NSTrackingArea fallback if `.onContinuousHover` proves unreliable on macOS 13 (risk noted in plan)
- Consider persisting selected time range across window open/close
- Consider adding export/screenshot capability for charts
