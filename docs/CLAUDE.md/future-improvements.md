# Future Improvements (Ideas)

## Automation

- [ ] **Auto-cleanup policies** — Auto-delete files when they exceed thresholds or age out. The settings infrastructure already exists (threshold values in `MonitorService`); needs the action logic to trigger deletion. Could include "delete oldest first" smart cleanup.
- [x] **FSEvents instead of polling** — Replace timer-based scanning with macOS `FSEvents` for instant detection and lower CPU usage. Current polling has 5–30 second detection latency depending on scan interval.
- [x] **File Write Watchdog** — Claude Code PreToolUse hook that blocks Write/Edit/Bash operations outside whitelisted directories. Managed via Settings UI with directory allowlist.

## Intelligence / Visibility

- [x] **Growth rate tracking** — Track file sizes across scans to show "growing at X MB/min." Useful for catching runaway agent output in real-time.
- [x] **Symlink scope indicators** — Visually distinguish files where the symlink target is safe to delete (within `/private/tmp/claude-` or `~/.claude/projects/`) vs out-of-scope (symlink-only removal), so users know what cleanup actually does.
- [x] **Deduplication visibility** — Show when multiple symlinks point to the same resolved file. The scan already deduplicates via `seenResolvedPaths` but this is invisible to the user.
- [x] **Statistics / historical graphs** — Track and display trends of temp file growth over time.
- [ ] **Export or logging** — Export current state or view historical cleanup operations.
- [ ] **Per-project file count in expanded view** — Total file count is shown in the status bar but not broken down per project.
- [ ] **Claude directory display** — `claudeDir` is stored per project but not displayed in the UI (shows as UUID like "claude-12345").
- [x] **Broken symlink cleanup action** — `isBrokenSymlink` flag is shown visually (red icon) but there's no dedicated action to clean up broken symlinks specifically.

## UX / Quality of Life

- [ ] **Configurable project name extraction** — Replace the hardcoded `skipWords` set in `extractProjectName()` with something that works for any user (e.g., infer from path depth, or let users set a project root).
- [x] **Search / filter projects** — Add a filter field for finding specific projects when the list is long.
- [x] **Sort options** — Files are always sorted by size descending. Add sort by name or modification date.
- [x] **Show file modification timestamps** — The data is already collected (`lastModified` on `MonitoredFile`) but never displayed in the UI.
- [x] **Batch operations on files** — Allow deleting individual files in bulk, not just entire projects.
- [ ] **Keyboard shortcuts for project actions** — Only global shortcuts exist (Cmd+R, Cmd+,, Cmd+Q). No keyboard shortcuts for project-level actions.
- [ ] **Favorite or ignore projects** — Prioritize monitoring certain projects or exclude others from scanning.
- [ ] **Stale threshold explanation** — Add a tooltip or explanation for the stale threshold setting, which isn't obvious in the UI.

## Polish

- [ ] **Actionable notifications** — Click notification to open popover, or add a "Delete" action directly from the system notification.
- [x] **Updater improvements** — Adopted Sparkle 2.x framework for auto-updates with EdDSA signature verification, native macOS update UI, and appcast feed. Replaced custom UpdateService.
- [ ] **Test target** — Add unit tests for `MonitorService.scan()` logic, `extractProjectName()`, and threshold calculations to catch regressions.

## Active Intelligence

- [x] **Active session detection** — Check if Claude Code is actively writing to a project (look for running `claude` processes or recent file modification within the last few seconds). Show a pulsing "live" badge on those projects. Prevents the #1 user mistake: accidentally deleting files an active Claude session still needs.
- [x] **Menubar trend indicator** — A tiny `↑` / `↓` / `→` arrow next to the size in the menubar showing whether total usage is growing, stable, or shrinking. The infrastructure already exists — `MonitorService` tracks `previousSizes` and computes growth rates per file. Rolling this up to a global trend is a few lines of code.
- [ ] **Intelligent cleanup suggestions** — Use heuristics to recommend what's safe to delete: files from sessions that ended >N hours ago (no growth rate), duplicate symlinks (where `duplicateCount > 1` — removing redundant links is free), and stale projects. Show a "Suggested cleanup: save ~X MB" banner.

## Operational Visibility

- [ ] **Watchdog audit log viewer** — The watchdog writes to `watchdog.log` but there's no UI for it. A simple scrollable log view (in Settings or its own window) showing blocked operations with timestamps, tool name, and the path that triggered the block.
- [ ] **Disk space context** — Show total tmp usage relative to available disk space: `"450 MB (0.2% of 200 GB free)"`. Could also trigger an additional "low disk" alert tier when Claude tmp files push free space below a threshold.
- [ ] **Space reclaimed tracker** — Track cumulative bytes deleted through the app over time. A "You've reclaimed 12.3 GB this month" stat in StatsView. The delete methods already know the sizes — just accumulate to a counter in `HistoryService`.
- [ ] **Snapshot diff ("What Changed")** — When opening the popover, briefly highlight what changed since last time: new projects (green), removed projects, significant size jumps (orange pulse). Answers "what happened while I wasn't looking?" at a glance.

## Watchdog Enhancements

- [ ] **Watchdog PostToolUse hook** — A companion hook that runs after tool execution to log what was actually written/modified — building an audit trail of what Claude did do, not just what it was blocked from doing. Claude Code supports `PostToolUse` hooks with the same schema.
- [ ] **Per-project watchdog scopes** — Instead of a single global allowlist, allow per-project directory restrictions. A web project might only need access to its own directory, while a monorepo project needs broader access. The `ClaudeProject` model already has the `path` and `claudeDir` to identify projects.

## System Integration

- [ ] **Disk pressure handler** — Register for macOS `NSWorkspace` disk space pressure notifications and auto-surface a cleanup prompt when the system is running low. Makes the app reactive to real OS-level pressure rather than just monitoring its own thresholds.
- [ ] **CLI companion** — A lightweight `scumbag-cli` binary (or XPC service) that can query app state, trigger scans, or run cleanup from the terminal. Useful for scripting (`scumbag-cli clean --stale`) or when users are already in a terminal session.
- [ ] **Option-click quick clean** — Hold Option while clicking the menubar icon to immediately clean all broken symlinks + stale projects without opening the popover. Power-user shortcut via `NSEvent.modifierFlags` check in the status item action handler.

## Notification Improvements

- [ ] **Notification digest mode** — Instead of one notification per file per threshold crossing, accumulate and send periodic summaries: `"3 projects grew past warning in the last hour, total +1.2 GB"`. Reduces notification fatigue for power users running many concurrent Claude sessions.
- [ ] **Per-project thresholds** — Allow different warning/critical thresholds per project. A data-heavy ML project routinely producing 500 MB files is different from a small web project doing the same. Per-project threshold overrides stored in UserDefaults keyed by project path.
