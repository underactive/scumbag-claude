# Plan: Dynamic Menubar Icon Color Based on Status

## Objective
Implement status-based menubar icon coloring. The icon turns orange at warning threshold and red at critical threshold, matching the colors used in the dropdown UI. Currently the icon is a static template PNG.

## Changes

### `Sources/ClaudeTmpMonitor/App.swift`
- Replace single `cachedMenuBarImage` with three pre-cached static images: `normalImage` (template), `warningImage` (orange-tinted), `criticalImage` (red-tinted)
- Add `tinted(with:)` static helper that creates a color-tinted copy of the menubar icon using `NSImage` drawing with `.sourceAtop` compositing
- Add `image(for:)` static helper that maps `MonitorStatus` to the corresponding cached image
- Update `MenuBarExtra` label to select image based on `monitor.status`

### No changes needed
- `MonitorService.swift` — `MonitorStatus` enum and `status` property already exist
- `ContentView.swift` — no UI changes needed
- No new asset files — tinting is done programmatically

## Dependencies
None — all changes are in a single file.

## Risks / Open Questions
- `lockFocus`/`unlockFocus` is deprecated in macOS 14+ but still functional. Could be replaced with `NSImage(size:flipped:drawingHandler:)` in a future update.
