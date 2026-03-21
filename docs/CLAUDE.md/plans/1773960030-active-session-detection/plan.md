# Plan: Active Session Detection

## Objective

Add active session detection to prevent users from accidentally deleting files from projects where Claude Code is actively writing. Projects with recent file activity (within 60 seconds) or positive growth rates show a pulsing green "live" badge.

## Changes

| File | Change |
|------|--------|
| `Sources/ClaudeTmpMonitor/MonitorService.swift` | Add `isActive` field to `ClaudeProject`, `activeSessionThreshold` constant, compute in `scan()`, carry through dedup rebuild |
| `Sources/ClaudeTmpMonitor/ContentView.swift` | Add `PulsingDot` view, green "live" badge in `projectRow()` |
| `CLAUDE.md` | Update MonitorService, ContentView descriptions, add active session detection paragraph to File Monitoring subsection |
| `docs/CLAUDE.md/testing-checklist.md` | Add 8 test items for active session detection |
| `docs/CLAUDE.md/future-improvements.md` | Mark active session detection as done |

## Dependencies

- `isActive` must be computed in `scan()` after `lastMod` and growth rates are available
- `PulsingDot` must be defined before its use in `projectRow()`
- No ordering constraints between documentation updates

## Design Decisions

- **60-second threshold**: 4x the default 15s scan interval. Conservative enough to avoid false positives.
- **Growth rate as secondary signal**: Catches files actively growing even if `lastModified` is slightly outside the 60s window.
- **No deletion interlock**: Badge is informational, not blocking. Follow-up if needed.
- **No process detection**: File modification recency is sufficient.
- **Not configurable**: Fixed threshold avoids Settings UI complexity.

## Risks / Open Questions

- None identified. The feature is purely additive — a new computed field and a conditional UI element.
