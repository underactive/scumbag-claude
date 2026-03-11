# Future Improvements (Ideas)

## Automation

- [ ] **Auto-cleanup policies** — Auto-delete files when they exceed thresholds or age out. The settings infrastructure already exists (threshold values in `MonitorService`); needs the action logic to trigger deletion. Could include "delete oldest first" smart cleanup.
- [x] **FSEvents instead of polling** — Replace timer-based scanning with macOS `FSEvents` for instant detection and lower CPU usage. Current polling has 5–30 second detection latency depending on scan interval.

## Intelligence / Visibility

- [x] **Growth rate tracking** — Track file sizes across scans to show "growing at X MB/min." Useful for catching runaway agent output in real-time.
- [x] **Symlink scope indicators** — Visually distinguish files where the symlink target is safe to delete (within `/private/tmp/claude-` or `~/.claude/projects/`) vs out-of-scope (symlink-only removal), so users know what cleanup actually does.
- [x] **Deduplication visibility** — Show when multiple symlinks point to the same resolved file. The scan already deduplicates via `seenResolvedPaths` but this is invisible to the user.
- [ ] **Statistics / historical graphs** — Track and display trends of temp file growth over time.
- [ ] **Export or logging** — Export current state or view historical cleanup operations.
- [ ] **Per-project file count in expanded view** — Total file count is shown in the status bar but not broken down per project.
- [ ] **Claude directory display** — `claudeDir` is stored per project but not displayed in the UI (shows as UUID like "claude-12345").
- [x] **Broken symlink cleanup action** — `isBrokenSymlink` flag is shown visually (red icon) but there's no dedicated action to clean up broken symlinks specifically.

## UX / Quality of Life

- [ ] **Configurable project name extraction** — Replace the hardcoded `skipWords` set in `extractProjectName()` with something that works for any user (e.g., infer from path depth, or let users set a project root).
- [ ] **Search / filter projects** — Add a filter field for finding specific projects when the list is long.
- [ ] **Sort options** — Files are always sorted by size descending. Add sort by name or modification date.
- [ ] **Show file modification timestamps** — The data is already collected (`lastModified` on `MonitoredFile`) but never displayed in the UI.
- [ ] **File preview or open** — View file contents or open them in an editor from the app.
- [ ] **Batch operations on files** — Allow deleting individual files in bulk, not just entire projects.
- [ ] **Keyboard shortcuts for project actions** — Only global shortcuts exist (Cmd+R, Cmd+,, Cmd+Q). No keyboard shortcuts for project-level actions.
- [ ] **Favorite or ignore projects** — Prioritize monitoring certain projects or exclude others from scanning.
- [ ] **Stale threshold explanation** — Add a tooltip or explanation for the stale threshold setting, which isn't obvious in the UI.

## Polish

- [ ] **Actionable notifications** — Click notification to open popover, or add a "Delete" action directly from the system notification.
- [ ] **Updater improvements** — Add checksum (SHA256) verification for downloaded updates, delta updates instead of full zip, or adopt Sparkle framework for more robust updating.
- [ ] **Test target** — Add unit tests for `MonitorService.scan()` logic, `extractProjectName()`, and threshold calculations to catch regressions.
