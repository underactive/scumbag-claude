# Implementation: Project Search & Sort Options

## Files Changed

- `Sources/ClaudeTmpMonitor/ContentView.swift` — added `ProjectSortOrder` enum, search/sort state, `searchSortBar` view, `noMatchesSection` view, `displayedProjects` computed property, `sortedFiles(_:)` helper; updated `ForEach` references in `projectsSection` and `filesSection`
- `CLAUDE.md` — updated ContentView description and File Inventory table to mention search/filter and sort
- `docs/CLAUDE.md/future-improvements.md` — checked off "Search / filter projects" and "Sort options"
- `docs/CLAUDE.md/testing-checklist.md` — added 14 test items under "Project Search & Sort" section
- `docs/CLAUDE.md/version-history.md` — added v0.4.4 entry

## Summary

Implemented exactly as planned. No deviations.

- `ProjectSortOrder` enum with `.size`, `.name`, `.date` cases
- Search field with magnifying glass icon and clear button, using `TextField` with `.plain` style in a subtle rounded background
- Sort menu using `Menu` + `Picker` with `.borderlessButton` style for automatic checkmarks
- `displayedProjects` filters by `localizedCaseInsensitiveContains` and sorts by the selected order
- `sortedFiles` applies the same sort order to files within expanded projects
- "No matching projects" empty state distinct from "No Claude tmp directories found"
- `brokenSymlinkCount` and "Clean All" still reference `monitor.projects` (all projects, not filtered)

## Verification

1. `swift build -c release` — clean build, no warnings or errors
2. Manual testing checklist items documented in `testing-checklist.md`

## Follow-ups

None identified.

## Audit Fixes

### Fixes applied

1. **Stale confirmDelete after search filter change** (State Management §1, Interface Contract §1, QA §1) — Added `.onChange(of: searchQuery) { _ in confirmDelete = nil }` to clear delete confirmation when the user types in the search field, preventing orphaned confirm/cancel buttons from reappearing after clearing a filter.
2. **Non-deterministic date sort with identical timestamps** (QA §2) — Added name as a secondary sort key (tiebreaker) in both `displayedProjects` and `sortedFiles` for the `.date` case, ensuring stable visual ordering.
3. **Search query persists across popover open/close** (QA §3, State Management §2, DX §6) — Added `searchQuery = ""` to the `.onAppear` block so the popover always opens showing all projects.
4. **Testing checklist precision** (Testing Coverage §4) — Split "search and sort state resets" into separate items: search resets on reopen, sort persists within session. Added delete confirmation interaction test item.

### Verification checklist

- [ ] Verify delete confirmation clears when typing in search field (open confirm on a project, then type — buttons should disappear)
- [ ] Verify date sort produces stable ordering when multiple files have the same lastModified
- [ ] Verify search field is empty when popover is opened after being closed with a search active
- [ ] `swift build -c release` passes after fixes (confirmed)

### Unresolved items

- [Medium] `displayedProjects` evaluated twice per render cycle — accepted at expected scale (single-digit project count). Would need caching if project counts grow significantly.
- [Medium] `sortedFiles` re-sorts already-sorted files for `.size` — accepted as defensive correctness.
- [Low] `expandedProjects` set may accumulate stale IDs — pre-existing, not introduced by this change.
