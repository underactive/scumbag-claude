# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.0] - 2026-03-19

### Added

- **Disk pressure detection**: system-level disk space monitoring via APFS-aware `volumeAvailableCapacityForImportantUsageKey` API, checking available space during each scan cycle
- Orange "Low Disk Space" banner in popover showing free space and Claude tmp usage when below configurable threshold (default: 10 GB)
- Episode-based notification dedup: fires once per pressure episode, resets on recovery; respects `notificationsEnabled` toggle
- Fail-open design: if volume query fails, no false alarm or banner
- New settings: `diskPressureEnabled` (default: true), `diskPressureThresholdGB` (default: 10, range: 1–500 GB) with toggle and conditional threshold row in Settings General tab
- **Active session detection**: projects with files modified within 60 seconds or actively growing show a pulsing green "live" badge with tooltip
- "stale" and "live" badges are mutually exclusive (active takes precedence)
- **Menubar trend indicator**: ↑/↓ arrows next to size in menubar showing whether total monitored size is growing or shrinking between scans, with 1 KB dead zone to filter noise

## [0.4.4] - 2026-03-19

### Added

- Search/filter field between status bar and project list: filters projects by display name (case-insensitive)
- Sort menu (Size/Name/Date) with checkmark on active selection; sort applies to both projects and files within expanded projects
- Compact relative timestamps ("2m", "3h", "2d", "Mar 15") on file rows next to size, and on project subtitles
- File selection circles on every file row for multi-file batch selection
- "Delete (N)" footer button for batch-deleting selected files with confirm/cancel flow
- `deleteFiles(_:)` method in MonitorService with symlink target deduplication
- `relativeTime(_:)` formatting function with static DateFormatter and future-date guard
- "No matching projects" empty state when search filter yields no results
- `selectedFileCount` computed property that intersects selection with current file IDs (accurate count after scans)
- Search query resets on popover open; sort order persists within session
- Delete confirmations clear when search query changes

## [0.4.3] - 2026-03-19

### Added

- Stacked bar charts color-coded by project for 24h/7d/30d time ranges in Statistics window
- Hover tooltips showing date header, total size, and per-project rows (color dot, name, size, percentage)
- 30-day time range added to Statistics
- Flow layout color legend below chart mapping colors to project names
- Retention hint when 30d range selected but history retention is below 30 days
- 12-color palette with deterministic project-to-color mapping

### Changed

- Statistics window enlarged to 700×550
- 1h range retains area+line chart; longer ranges use stacked bars

## [0.4.2] - 2026-03-19

### Added

- Tabbed Settings window: 3-tab TabView (General, File Operations, Blocked Commands)
- Independent watchdog toggles: `fileOpsEnabled` for directory-based checks, `commandWatchdogEnabled` for blocked commands
- Migration from legacy `watchdogEnabled` key to split toggles
- Explanatory help text and shared hook status indicator on each watchdog tab

### Changed

- Hook script conditionally generated based on enabled features; matcher adapts (`Write|Edit|Bash` vs `Bash`)
- `shellEscape()` strips control characters
- `regenerateHookScript()` recovers from externally-deleted script
- `ForEach` uses stable element identity

## [0.4.1] - 2026-03-19

### Added

- Configurable blocked commands list in file write watchdog: inherently dangerous commands (`passwd`, `sudo`, `su`, `shutdown`, `reboot`, `halt`, `poweroff`, `mkfs`, `newfs`, `diskutil`, `csrutil`, `nvram`, `dscl`) are rejected regardless of target directory
- Position-aware regex matching `(^\s*|[|;&]\s*)cmd(\s|$)` avoids false positives on path arguments (e.g., `cat /etc/passwd` is allowed)
- Blocked commands UI in Settings: scrollable list with inline remove buttons, text field + "Add" button
- Input validation restricts command names to `[a-zA-Z0-9_-]` to prevent regex/shell injection
- Load-time sanitization filters invalid command names from UserDefaults

### Changed

- Settings window is now resizable to accommodate blocked commands list
- Watchdog hook script includes `BLOCKED_CMDS` check before destructive pattern detection

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
