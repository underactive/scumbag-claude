# Plan: Settings Dialog + Right-Click About Menu

## Objective

Move settings from inline menubar popover to a separate dialog window, and add a right-click context menu on the menubar icon with "About Scumbag Claude" and "Quit" items. Replace `MenuBarExtra` with custom `NSStatusItem` to support right-click handling.

## Changes

| File | Action | Description |
|------|--------|-------------|
| `Sources/ClaudeTmpMonitor/App.swift` | Major rewrite | Replace `MenuBarExtra` with `NSStatusItem` in `AppDelegate`. Left-click shows `NSPopover`, right-click shows `NSMenu`. Singleton `NSWindow` helpers for Settings and About. Combine subscriber for reactive icon updates. |
| `Sources/ClaudeTmpMonitor/ContentView.swift` | Modify | Remove inline settings section and `settingRow` helper. Add `onOpenSettings` closure property. Update gear button to call closure. |
| `Sources/ClaudeTmpMonitor/SettingsView.swift` | New file | Extracted settings UI with threshold/interval rows, notifications toggle, launch at login toggle. |
| `Sources/ClaudeTmpMonitor/AboutView.swift` | New file | About dialog with app icon, name, version, GitHub link. |
| `CLAUDE.md` | Update | Update Architecture, File Inventory, Data Flow sections. |
| `docs/CLAUDE.md/testing-checklist.md` | Update | Add sections for settings window, about dialog, right-click menu. |

## Dependencies

- `SettingsView` and `AboutView` must exist before `App.swift` can reference them
- `MonitorService` unchanged — no dependencies on that file

## Risks / Open Questions

- `Bundle.main.infoDictionary` may not contain version when running outside `.app` bundle (falls back to "Unknown")
- `NSApp.applicationIconImage` may return generic icon if not running from `.app` bundle
