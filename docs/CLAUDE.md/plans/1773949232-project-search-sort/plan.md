# Plan: Project Search & Sort Options

## Objective

The popover's project list can grow long when many Claude projects are active. Currently there's no way to find a specific project or change the sort order (always size descending). This adds a search/filter field and sort options to improve navigation.

## Changes

### 1. `Sources/ClaudeTmpMonitor/ContentView.swift`

- Add `ProjectSortOrder` enum (`.size`, `.name`, `.date`)
- Add `@State` vars for `searchQuery` and `sortOrder`
- Add `searchSortBar` view: compact `TextField` with magnifying glass + clear button, `Menu` with `Picker` for sort order (checkmark on active)
- Add `noMatchesSection` view for when filter has no results
- Add `displayedProjects` computed property: filters by `searchQuery`, sorts by `sortOrder`
- Add `sortedFiles(_:)` helper: sorts files within expanded projects by the same `sortOrder`
- Update `projectsSection` `ForEach` to use `displayedProjects`
- Update `filesSection(for:)` `ForEach` to use `sortedFiles(project.files)`
- Search bar only shown when `!monitor.projects.isEmpty`
- `brokenSymlinkCount` and "Clean All" continue to reference all projects (not filtered)

### 2. Documentation updates

- `CLAUDE.md` — update ContentView description to mention search/filter and sort
- `docs/CLAUDE.md/testing-checklist.md` — add test items
- `docs/CLAUDE.md/future-improvements.md` — check off the two items
- `docs/CLAUDE.md/version-history.md` — add entry

No version bump (still 0.4.3 in Info.plist, unreleased).

## Dependencies

No ordering constraints — all changes are within a single file plus documentation.

## Risks / Open Questions

- **Dynamic popover height**: search bar adds ~36px; `sizingOptions = .preferredContentSize` handles this automatically via the existing `ProjectsHeightKey` preference
- **Sort persists across scans**: `@State` survives re-renders; sort/filter re-applied as `monitor.projects` updates
- **Clean All while filtered**: operates on ALL projects (not just visible), consistent with current behavior
- **`@State` resets on popover close**: intentional — search/sort are ephemeral per session
