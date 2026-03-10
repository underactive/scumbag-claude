# Auto-Update Feature Plan

## Objective

Add automatic update checking against GitHub releases API, an in-popover update banner, and a one-click download + install + relaunch flow. Users currently must manually check for and download updates.

## Changes

### New Files
- `Sources/ClaudeTmpMonitor/UpdateService.swift` — `@MainActor class UpdateService: ObservableObject` with update checking, downloading, self-replacement, and version comparison logic

### Modified Files
- `Sources/ClaudeTmpMonitor/MonitorService.swift` — Add `SettingsKey` constants for update settings
- `Sources/ClaudeTmpMonitor/App.swift` — Wire `UpdateService` ownership, environment injection, "Check for Updates..." right-click menu item
- `Sources/ClaudeTmpMonitor/ContentView.swift` — Add update banner section between projects and footer
- `Sources/ClaudeTmpMonitor/SettingsView.swift` — Add "Check for updates automatically" toggle
- `Sources/ClaudeTmpMonitor/AboutView.swift` — Add update status text below version
- `CLAUDE.md` — Document new subsystem, settings, file inventory

## Dependencies

1. `MonitorService.swift` SettingsKey additions must come first (no functional change)
2. `UpdateService.swift` depends on SettingsKey constants
3. `App.swift` depends on UpdateService
4. `ContentView.swift`, `SettingsView.swift`, `AboutView.swift` depend on UpdateService environment object

## Risks / Open Questions

1. **Gatekeeper quarantine** — Mitigated by `xattr -cr` in update script
2. **Permissions on /Applications** — Pre-checked with `isWritableFile`
3. **Dev mode bundle path** — Detected and shows manual update message
4. **GitHub rate limiting** — 24h interval = ~1 req/day, well within 60/hr limit
5. **No checksum verification** — Acceptable for HTTPS download; could add SHA256 later
