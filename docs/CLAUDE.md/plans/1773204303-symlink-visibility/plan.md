# Plan: Symlink Visibility & Broken Symlink Cleanup

## Objective

Implement three related features that make symlink behavior transparent to users:

1. **Symlink scope indicators** — Show whether a symlink's target is within the safe deletion scope (will be fully deleted) or out-of-scope (only the symlink entry is removed, target preserved).
2. **Deduplication visibility** — Show when multiple symlinks point to the same resolved file, since the scan deduplicates via `seenResolvedPaths` but this is invisible to users.
3. **Broken symlink cleanup action** — Provide a dedicated "Clean Broken" action to remove all broken/dangling symlinks at once.

## Changes

### `Sources/ClaudeTmpMonitor/MonitorService.swift`

- **MonitoredFile struct**: Add `isTargetInScope: Bool` (whether symlink target is in allowed deletion scope) and `duplicateCount: Int` (how many files share the same resolved path, default 1).
- **ClaudeProject struct**: Add computed `brokenSymlinkCount: Int`.
- **scanDirectory()**: Set `isTargetInScope` using existing `isInAllowedDeletionScope()` for symlinks; `true` for regular files and broken symlinks (no target to worry about).
- **scan()**: After building all projects, compute a global `resolvedPath → count` frequency map across all project files. Rebuild project files with `duplicateCount` values if any duplicates exist.
- **New method `deleteBrokenSymlinks()`**: Delete all broken symlink entries across all projects. Only removes the dangling symlink file itself (no target exists).
- **New method `deleteBrokenSymlinksInProject(_:)`**: Same but scoped to a single project.

### `Sources/ClaudeTmpMonitor/ContentView.swift`

- **DeleteConfirmation enum**: Add `.brokenSymlinks` and `.brokenSymlinksInProject(String)` cases.
- **fileRow()**: For out-of-scope symlinks, show "link only" pill badge to indicate deletion only removes the symlink. For files with `duplicateCount > 1`, show "×N" badge.
- **footerSection**: Add "Clean Broken (N)" button when broken symlinks exist globally, with confirm/cancel flow.

## Dependencies

- `isTargetInScope` depends on existing `isInAllowedDeletionScope()` — no new logic needed, just exposing the result.
- `duplicateCount` requires all projects to be scanned before computing — needs a post-processing pass in `scan()`.
- Broken symlink cleanup is independent of the other two features.

## Risks / Open Questions

- **Struct reconstruction overhead**: Computing `duplicateCount` requires rebuilding all `MonitoredFile` and `ClaudeProject` structs in a second pass. This is negligible given typical project counts but adds code verbosity.
- **Cross-project deduplication**: The current `seenResolvedPaths` in `scanDirectory()` is per-project. The new `duplicateCount` correctly spans all projects.
