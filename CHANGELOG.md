# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - 2026-03-15

### Added

- Statistics window with SwiftUI Charts: area + line chart of total temp directory size over time
- Segmented time range picker (1h, 24h, 7d) with current/peak/average summary stats
- HistoryService: records scan snapshots with two-tier aggregation (raw resolution ≤1h, 5-minute buckets beyond)
- JSON persistence to `~/Library/Application Support/com.esison.claude-tmp-monitor/history.json` with 60s auto-save + save on quit
- Configurable history retention (1–30 days, default 7) in Settings
- "Stats" button in popover footer and "Statistics" item in right-click menu
- Empty state in chart when fewer than 2 data points exist
- `MonitorService.onScanComplete` callback to bridge scan results to HistoryService
- **File Write Watchdog**: Claude Code PreToolUse hook that blocks Write/Edit/Bash operations targeting files outside user-whitelisted directories
- Watchdog section in Settings: toggle, directory allowlist with folder picker, hook installation status indicator
- WatchdogService: generates bash hook script with JXA (`osascript -l JavaScript`) JSON parsing, patches `~/.claude/settings.local.json`
- Bash destructive pattern detection: `rm`, `rmdir`, `unlink`, `mv`, `cp`, `ln`, `tee`, `dd`, `curl -o`, `wget -O`, `>`, `>>`, `chmod`, `chown`, `chflags`, `git clean`, `git checkout --`
- Pure-string path normalization to prevent `..` traversal bypasses
- Trailing-slash prefix matching to prevent directory name confusion (e.g. `/DevelopmentEvil` vs `/Development`)
- macOS notifications and logging for blocked operations (`watchdog.log`)
- Fail-open design: hook allows operations if JSON parsing fails
- `matcher` field in hook entry restricts invocation to Write/Edit/Bash tools only
- Guard against corrupted `settings.local.json`: refuses to overwrite invalid JSON

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
