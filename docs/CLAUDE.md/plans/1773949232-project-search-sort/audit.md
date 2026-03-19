# Audit Report: Project Search & Sort Options

## Files Changed

- `Sources/ClaudeTmpMonitor/ContentView.swift`

## QA Audit

1. **[FIXED] [Medium] `confirmDelete` state can become stale when search hides target project.** If the user opens a delete confirmation then types a search query that filters out that project, the confirmation state persists invisibly. Fixed by clearing `confirmDelete` via `.onChange(of: searchQuery)`.
2. **[FIXED] [Low] Date sort non-deterministic with identical timestamps.** `Swift.sorted` is not stable; files with the same `lastModified` could flicker between renders. Fixed by adding name as a tiebreaker in both `displayedProjects` and `sortedFiles`.
3. **[FIXED] [Low] `searchQuery` persists across popover open/close.** @State may survive if the popover retains its view. Fixed by resetting `searchQuery = ""` in `.onAppear`.
4. [Medium] `displayedProjects` computed property evaluated twice per render (`.isEmpty` check and `ForEach`). Acceptable at expected project counts (single-digit to low double-digit).
5. [Medium] `sortedFiles` re-sorts files already sorted by MonitorService when `sortOrder == .size`. Redundant but harmless; ensures correctness regardless of MonitorService internals.
6. [Low] Search filters by `displayName` only, not path or `claudeDir`. Design choice — display name is the user-facing label.
7. [Low] Default sort `.size` correctly replicates prior behavior. Confirmed non-issue.
8. [Low] `sortOrder` persists within session across popover open/close. Desirable UX — user preference should stick.

## Security Audit

No security issues found. `searchQuery` is used only in `localizedCaseInsensitiveContains` and rendered via SwiftUI `Text` (no injection surface). No array index access, no force-unwraps.

## Interface Contract Audit

1. **[FIXED] [Medium] `confirmDelete` can reference a project filtered out of `displayedProjects`.** Same as QA finding #1. Fixed.
2. **[FIXED] [Medium] Broken symlink `lastModified` in date sort.** Verified: broken symlinks get `Date.distantPast` from `MonitorService.scan()` (line 618), sorting them to the bottom in date-descending order. Correct behavior. Tiebreaker fix ensures stable order among broken symlinks.
3. [Low] `expandedProjects` set may retain stale project IDs. Pre-existing behavior, negligible memory growth.
4. [Low] Confirmed: `brokenSymlinkCount` and "Clean All" correctly reference `monitor.projects` (all projects, not filtered).

## State Management Audit

1. **[FIXED] [Medium] `confirmDelete` stale after filter change.** Same as QA/Interface findings. Fixed.
2. **[FIXED] [Low] `searchQuery` ephemeral state lifecycle.** Fixed with onAppear reset.
3. [Low] `displayedProjects` is a pure computed property with clean data flow. No multiple sources of truth. Positive finding.
4. [Low] `expandedProjects` unbounded growth. Pre-existing, not introduced by this change.

## Resource & Concurrency Audit

No issues found. All new state is view-local `@State`. Computed properties are pure and synchronous. No new timers, subscriptions, or async operations introduced.

## Testing Coverage Audit

1. [Medium] Missing: expanded project still shows all files (not filtered by search). Covered implicitly by "Switching sort order reorders files within expanded projects" — search operates at project level only.
2. [Medium] Missing: search field keyboard interaction (Escape may close popover). Accepted — standard macOS popover behavior, not specific to this feature.
3. [Low] Missing: accessibility labels for search/sort controls in accessibility checklist section. Minor — controls have `.accessibilityLabel()` set, VoiceOver reads them.
4. Updated: split "search and sort resets" checklist item into separate items for search (resets) and sort (persists within session). Added delete confirmation interaction test.

## DX & Maintainability Audit

1. [Medium] `displayedProjects` evaluated multiple times per render. Acceptable at expected scale.
2. [Low] `sortedFiles` duplicates sorting logic pattern from `displayedProjects`. Different types (`ClaudeProject` vs `MonitoredFile`) require different property access — not easily abstractable without protocol overhead.
3. [Low] Magic number `0.06` for search background opacity. Consistent with other ad-hoc opacity values in the file.
4. [Low] `ProjectSortOrder` raw values serve as display labels. Not persisted to UserDefaults, so no coupling issue.
