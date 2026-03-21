# Plan: File Timestamps, Open in Editor, and Batch Delete

## Objective

Three UX improvements to file rows in the popover's project list:
1. Show modification timestamps on files and projects
2. Allow opening files in the default editor
3. Allow selecting and batch-deleting multiple files

## Changes

### 1. `Sources/ClaudeTmpMonitor/MonitorService.swift`

**New top-level function:**
```swift
func relativeTime(_ date: Date) -> String
```
Returns compact relative time: "now", "2m", "3h", "2d", or "Mar 15" for older dates. Placed alongside `formatBytes` and `formatGrowthRate`.

**New method:**
```swift
func deleteFiles(_ files: [MonitoredFile])
```
Batch-deletes multiple files with a single scan at the end. Same symlink-target-scope logic as `deleteFile`, but collects all errors before scanning once.

### 2. `Sources/ClaudeTmpMonitor/ContentView.swift`

**State additions:**
```swift
@State private var selectedFiles: Set<String> = []
```

**DeleteConfirmation addition:**
```swift
case selectedFiles
```

**fileRow changes:**
- Add selection circle toggle (left side, before file icon): empty circle / filled checkmark
- Add relative timestamp after size: `3.2 MB · 2m` in caption2, secondary color
- Add "open" icon button between growth rate and delete button (hidden for broken symlinks)
- Opens `file.resolvedPath` via `NSWorkspace.shared.open(URL(fileURLWithPath:))`

**projectRow changes:**
- Add relative timestamp to subtitle: `50 files · claude-503 · 2m ago`

**Footer changes:**
- "Delete Selected (N)" button appears when `selectedFiles` is non-empty
- Same confirm/cancel flow as other delete operations
- Uses `monitor.deleteFiles(...)` to batch-delete, then clears selection

**State cleanup:**
- Clear `selectedFiles` in `.onAppear`
- Clear `selectedFiles` after batch deletion
- Clear stale IDs from `selectedFiles` after "Clean All" / project delete

### 3. Documentation updates

- `CLAUDE.md` — update ContentView description
- `docs/CLAUDE.md/future-improvements.md` — check off 3 items
- `docs/CLAUDE.md/testing-checklist.md` — add test items
- `docs/CLAUDE.md/version-history.md` — add entry

## Edge cases

- **Broken symlinks**: no timestamp (Date.distantPast), no open button, selectable for batch delete
- **Selection + search filter**: selection persists across filter changes (IDs are stable paths)
- **Selection + scan**: stale IDs in set are harmless (files no longer exist in next render)
- **Selection + project collapse**: selection persists, restored when project re-expands
- **Open file fails**: NSWorkspace.open returns Bool; silently fails if no handler for file type
- **Popover width**: selection circle adds ~18px; compensated by reducing file section left padding

## Files to modify

1. `Sources/ClaudeTmpMonitor/MonitorService.swift` — `relativeTime()`, `deleteFiles()`
2. `Sources/ClaudeTmpMonitor/ContentView.swift` — timestamps, open button, selection, batch delete
3. `CLAUDE.md` — ContentView description
4. `docs/CLAUDE.md/testing-checklist.md` — new test items
5. `docs/CLAUDE.md/future-improvements.md` — check off items
6. `docs/CLAUDE.md/version-history.md` — add entry
