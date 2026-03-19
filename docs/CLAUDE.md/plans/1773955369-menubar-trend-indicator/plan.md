# Plan: Menubar Trend Indicator

## Objective

Add a tiny ↑ / ↓ / → arrow next to the size in the menubar showing whether total disk usage by Claude temp files is growing, stable, or shrinking. The arrow is derived by comparing `totalSize` across consecutive scans, with a 1 KB dead zone to filter filesystem noise.

## Changes

### `Sources/ClaudeTmpMonitor/MonitorService.swift`
- **Add `SizeTrend` enum** near `MonitorStatus`: three cases (`.growing`, `.stable`, `.shrinking`) with an `indicator` computed property returning the corresponding arrow character.
- **Add `@Published var sizeTrend: SizeTrend = .stable`** to `MonitorService` — published so the menubar Combine subscriber can react.
- **Add `private var previousTotalSize: UInt64?`** — tracks the total from the previous scan.
- **In `scan()`**, after computing `totalSize`, compare to `previousTotalSize` with a 1 KB threshold to set `sizeTrend`, then store current `totalSize` as `previousTotalSize`.

### `Sources/ClaudeTmpMonitor/App.swift`
- **Extend Combine subscriber** from 3-way `combineLatest` to 4-way by adding `monitor.$sizeTrend`.
- **Update `updateStatusItemAppearance`** to accept `SizeTrend` parameter and append `trend.indicator` to the menubar title when size is shown.

### `CLAUDE.md`
- Document `sizeTrend` in the Architecture and Settings sections.

## Dependencies

None — all changes are additive. `MonitorService` already computes `totalSize` each scan.

## Risks / open questions

- **First scan**: `previousTotalSize` is `nil`, so trend defaults to `.stable` (no prior data to compare).
- **1 KB dead zone**: chosen to filter sub-KB filesystem metadata noise. May need tuning if users report flicker, but 1 KB is well below the MB-scale files this app monitors.
- **Stable arrow (→) visual noise**: showing → when nothing changes could feel cluttered. Implemented as specified; can be revisited if feedback indicates users prefer hiding the arrow when stable.
