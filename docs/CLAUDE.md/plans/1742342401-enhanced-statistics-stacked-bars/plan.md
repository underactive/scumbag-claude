# Plan: Enhanced Statistics with Stacked Bar Charts

## Objective

Enhance the Statistics window to show stacked bar charts color-coded by project for 24h/7d/30d ranges, with hover tooltips showing per-project distribution (size in MB, percentage), a project color legend, and a new 30-day time range option.

## Changes

### 1. `Sources/ClaudeTmpMonitor/HistoryService.swift`
- Add `.thirtyDays` case to `TimeRange` enum (2,592,000 seconds)

### 2. `Sources/ClaudeTmpMonitor/StatsView.swift` (major rewrite)
- Add `ChartBar` data model for aggregated bar data
- Add `aggregateBars(from:range:)` helper for calendar-aligned bucketing
- Add 12-color palette with deterministic project-to-color mapping
- Dual chart rendering: area+line for 1h, stacked BarMark for 24h/7d/30d
- Hover tooltip via `.chartOverlay` + `.onContinuousHover`
- Flow layout legend below chart
- Retention hint when 30d selected but retention < 30 days
- Wider segmented picker (240px) for 4 segments

### 3. `Sources/ClaudeTmpMonitor/App.swift`
- Bump stats window content size from 600×450 to 700×550

### 4. Documentation
- Update CLAUDE.md, Info.plist, version-history.md, testing-checklist.md

## Dependencies

1. HistoryService `.thirtyDays` must exist before StatsView compiles
2. StatsView rewrite independent of App.swift window size change
3. Documentation after all code changes

## Risks / open questions

- `.onContinuousHover` inside `.chartOverlay` may not fire reliably on macOS 13 — fallback to NSTrackingArea if needed
- `proxy.value(atX:)` returns continuous Date — snap to bucket start via Calendar
- >12 projects: colors repeat via modulo; tooltip disambiguates by name
