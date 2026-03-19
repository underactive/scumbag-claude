# Implementation: Menubar Trend Indicator

## Files changed

- `Sources/ClaudeTmpMonitor/MonitorService.swift` — Added `SizeTrend` enum, `@Published var sizeTrend`, `private var previousTotalSize`, and trend computation in `scan()`
- `Sources/ClaudeTmpMonitor/App.swift` — Extended 3-way `combineLatest` to 4-way with `$sizeTrend`, updated `updateStatusItemAppearance` to append trend arrow to menubar title
- `CLAUDE.md` — Updated Architecture descriptions for App.swift and MonitorService.swift, added trend indicator documentation to Status & Notifications subsection, updated Data Flow
- `docs/CLAUDE.md/future-improvements.md` — Marked menubar trend indicator as complete
- `docs/CLAUDE.md/testing-checklist.md` — Added Menubar Trend Indicator section with 7 test items

## Summary

Implemented as planned with one post-audit refinement: the stable arrow `→` was suppressed in favor of showing no arrow when stable, based on consistent feedback across 4 of 7 audit subagents. The `SizeTrend` enum provides three states (`.growing` ↑, `.stable` (hidden), `.shrinking` ↓). The trend is computed at the end of each `scan()` by comparing `totalSize` to `previousTotalSize` with a 1 KB dead zone. The Combine subscriber in `AppDelegate` was extended from 3-way to 4-way `combineLatest` to include the new `$sizeTrend` publisher, and the menubar title string conditionally appends the trend arrow after the formatted size.

## Verification

- `swift build` succeeds with no errors or warnings
- Code review confirms trend computation is placed after `totalSize` assignment and before `previousSizes` rebuild
- First scan correctly defaults to `.stable` (no `previousTotalSize` to compare)
- Dead zone comparison uses unsigned arithmetic safely (no underflow risk since both sides add the threshold)

## Follow-ups

- A user-facing toggle to enable/disable the trend arrow independently of size display could be added if requested

## Audit Fixes

### Fixes applied

1. **Suppressed stable arrow** — Changed `SizeTrend.stable.indicator` from `"→"` to `""` and updated `updateStatusItemAppearance` to conditionally append the trend suffix only when non-empty. Addresses QA Audit §5, Interface Contract Audit §4, DX Audit §2, and State Management Audit §1.
2. **Extracted threshold constant** — Moved `changeThreshold` from a local variable in `scan()` to `private static let trendChangeThreshold` at class level. Addresses DX Audit §1.
3. **Added doc comment to `SizeTrend`** — Added a one-line doc comment explaining the enum's purpose and dead zone semantics. Addresses DX Audit §3 (renamed §4 in audit report).
4. **Added boundary test to checklist** — Added "Change of exactly 1024 bytes shows no arrow (stable, boundary test)" item. Addresses Testing Coverage Audit §2.

### Verification checklist

- [ ] Build succeeds after all fixes
- [ ] Menubar shows no trailing arrow when trend is stable (just size, e.g., "42.3 MB")
- [ ] Menubar shows "42.3 MB ↑" when growing
- [ ] Menubar shows "42.3 MB ↓" when shrinking
- [ ] No trailing whitespace in menubar title when stable

### Unresolved items

- **No automated test target** (Testing Coverage Audit §1, §3) — Pre-existing limitation; the project has no test target. Manual testing checklist provides behavioral coverage. Deferred to future work.
- **Rapid successive scans note** (Testing Coverage Audit §4) — The checklist adequately covers the feature without this edge case note. Accepted as-is.
