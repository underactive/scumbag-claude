# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-03-09

### Added

- Settings dialog: moved settings out of the menubar popover into a separate window (Cmd+, or gear button)
- Right-click context menu on menubar icon with "About Scumbag Claude" and "Quit"
- About dialog with app icon, name, version, and GitHub link
- Dynamic menubar icon color: orange at warning threshold, red at critical threshold, system-tinted template icon for normal status
- Batch "Clean All" deletion (deletes all projects in one pass, single rescan)
- Accessibility labels and keyboard shortcuts (Cmd+R refresh, Cmd+, settings, Cmd+Q quit)
- VoiceOver labels for all interactive controls
- Notification permission detection with "denied" warning in settings
- SF Symbol fallback icon when menubar icon resource is missing

### Changed

- Replaced SwiftUI `MenuBarExtra` with custom `NSStatusItem`/`NSPopover`/`NSMenu` architecture
- `AppDelegate` now owns `MonitorService` (previously `@StateObject` in `App` struct)
- Reactive menubar updates via Combine subscriber on status/size changes
- Settings values clamped to valid ranges on load and on change
- Typed `DeleteConfirmation` enum replaces raw string tracking for delete confirmations
- Confirmation state resets when popover reopens (no stale confirm/cancel buttons)
- Timer uses `.tolerance` for energy efficiency
- Pluralization fixed ("1 file" not "1 files")

### Fixed

- Symlink deletion validates target path against allowlist before removing (prevents deleting files outside `/private/tmp/claude-` and `~/.claude/projects/`)
- Settings/About windows reuse existing instances instead of recreating on each open
- Force-unwrapped URL replaced with safe optional binding

### Removed

- Deprecated `NSUserNotificationAlertStyle` from Info.plist (replaced with `NSPrincipalClass`)
- Dead code: unused `MonitorStatus.iconName`, `MonitorService.statusIcon`, unused `projectDisplayName` parameter

## [0.1.0] - 2026-03-09

### Added

- macOS menubar app using SwiftUI `MenuBarExtra` with `.window` style
- Timer-based polling of `/private/tmp/claude-*/` directories (configurable interval, default 30s)
- Symlink resolution for accurate file size reporting with deduplication by resolved path
- Per-project file grouping with expandable details in the menubar dropdown
- Three-tier status system (Normal/Warning/Critical) with color-coded menubar icon
- System notifications on threshold crossings (once per file per threshold)
- Inline delete with confirmation for individual files, projects, and bulk cleanup
- Stale directory detection based on configurable age threshold (default 7 days)
- Configurable settings: warning/critical thresholds, scan interval, stale days, notifications toggle
- Launch-at-login support via macOS `ServiceManagement` (`SMAppService`)
- Menubar-only mode (no Dock icon) via `LSUIElement` in Info.plist with programmatic fallback
- App icon and menubar status icons (normal/warning/critical variants)
- Makefile with build, bundle, install, run, and clean targets
- README with build instructions and feature overview
