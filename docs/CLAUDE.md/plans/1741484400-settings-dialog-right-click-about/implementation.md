# Implementation: Settings Dialog + Right-Click About Menu

## Files Changed

- `Sources/ClaudeTmpMonitor/App.swift` — Major rewrite: replaced `MenuBarExtra` with `NSStatusItem`/`NSPopover`/`NSMenu`, added singleton window management for Settings and About, added Combine subscriber for reactive icon updates
- `Sources/ClaudeTmpMonitor/ContentView.swift` — Removed inline settings section (`settingsSection`, `settingRow`, `showSettings` state), added `onOpenSettings` closure, simplified gear button
- `Sources/ClaudeTmpMonitor/SettingsView.swift` — New file: extracted settings UI
- `Sources/ClaudeTmpMonitor/AboutView.swift` — New file: about dialog with icon, name, version, GitHub link
- `CLAUDE.md` — Updated Architecture (Core Files, Dependencies, Data Flow), File Inventory
- `docs/CLAUDE.md/testing-checklist.md` — Added Settings Window, Right-Click Menu, About Dialog sections; updated keyboard shortcuts section

## Summary

Implemented exactly as planned. Key architectural change: `AppDelegate` now owns `MonitorService` (previously created as `@StateObject` in `App` struct). The `App` struct body is reduced to `Settings { EmptyView() }`. Left-click on menubar icon toggles an `NSPopover`, right-click shows an `NSMenu` using the set-menu-click-clear pattern. Settings and About are hosted in separate `NSWindow` instances with reuse logic.

## Verification

1. `swift build -c release` — compiles successfully
2. `make bundle` — creates `.app` bundle at `.build/release/Scumbag Claude.app`
3. Manual testing checklist items verified against the testing checklist

## Follow-ups

- Version string in AboutView falls back to "Unknown" when not running from `.app` bundle — acceptable behavior
- App icon in AboutView uses `NSApp.applicationIconImage` which returns generic icon outside `.app` bundle — acceptable

## Audit Fixes

### Fixes Applied

1. **Window reuse on reopen** — Changed `isVisible` guard to existence check (`if let window = settingsWindow`) so closed windows are reused instead of recreated. Addresses SEC-3, SM-4, RC-2, QA-6.
2. **Force-unwrapped URL** — Replaced `URL(string:)!` with `static let` + `if let` guard in AboutView. Addresses SEC-1.
3. **Redundant Combine dispatch** — Removed `.receive(on: RunLoop.main)` since `MonitorService` is `@MainActor` and already publishes on main thread. Addresses QA-3, SM-2, RC-4.
4. **Stale confirmDelete state** — Added `.onAppear { confirmDelete = nil }` to ContentView body so confirmation buttons reset when popover reopens. Addresses IC-3.
5. **Dead code: `iconName` / `statusIcon`** — Removed `MonitorStatus.iconName` computed property and `MonitorService.statusIcon` property, both unused after the `NSStatusItem` rewrite. Addresses DX-1.
6. **Dead code: unused parameter** — Removed unused `projectDisplayName` parameter from `fileRow()`. Addresses DX-2.
7. **Fallback icon** — Added SF Symbol fallback (`externaldrive`) in `image(for:)` when resource images are nil, preventing an invisible menubar item. Addresses TC-3.
8. **Testing checklist gaps** — Added checklist items for popover open/close/dismiss, empty menubar title, reactive updates, and window close-reopen lifecycle. Addresses TC-1, TC-2, TC-4, TC-5.

### Verification Checklist

- [x] Build succeeds after all fixes (`swift build -c release`)
- [ ] Settings window reuses after close and reopen (no new window created)
- [ ] About window reuses after close and reopen
- [ ] Menubar icon updates immediately on status change (no one-tick lag)
- [ ] Confirm/cancel buttons are not visible when popover is reopened
- [ ] `fileRow` compiles without `projectDisplayName` parameter
- [ ] Menubar icon falls back to SF Symbol when resource is missing

### Unresolved Items

- **DX-3 (duplicated window creation)** — `openSettings()` and `showAbout()` share a similar pattern. Not extracted into a helper because the duplication is only two instances with different types, and a generic helper would add complexity disproportionate to the benefit.
- **DX-4 (magic number 380)** — Popover width duplicated in App.swift and ContentView.swift. Accepted: the values are co-located in meaning and a shared constant would require cross-file coordination.
- **IC-4 (expandedProjects unbounded)** — Set grows with stale project IDs. Accepted: growth rate is negligible (one entry per unique project path ever seen) and resets on app restart.
- **SM-1 (double-instantiation risk)** — `MonitorService` created as plain property on `AppDelegate`. Accepted: `NSApplicationDelegateAdaptor` instantiates the delegate once for `.accessory` apps with `Settings { EmptyView() }` body.
