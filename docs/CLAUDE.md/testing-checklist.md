# Testing Checklist

## Core Functionality
- [ ] App launches as menubar icon (no Dock icon)
- [ ] Menubar shows icon and size text when tmp files exist
- [ ] Menubar shows only the icon (no size text) when no tmp files exist
- [ ] Left-clicking the menubar icon opens the popover panel
- [ ] Left-clicking the menubar icon again closes the popover
- [ ] Clicking outside the popover closes it (transient behavior)
- [ ] Menubar icon and size text update automatically after a background scan completes
- [ ] Scan runs automatically on configured interval
- [ ] Manual refresh via Cmd+R or refresh button triggers scan
- [ ] Projects list shows all detected claude tmp directories
- [ ] Expanding a project shows its files sorted by size descending
- [ ] File sizes are color-coded: red >= critical, orange >= warning, default otherwise
- [ ] Stale projects show "stale" badge

## File Deletion
- [ ] Clicking trash icon on a project shows confirm/cancel buttons
- [ ] Clicking xmark on a file shows confirm/cancel buttons
- [ ] Confirming deletion removes the file/project from the list
- [ ] Symlink targets outside allowed scope (not /private/tmp/claude- or ~/.claude/projects/) are not deleted
- [ ] Clean All deletes all projects and refreshes the list
- [ ] Deletion errors appear in the footer as red text

## Settings Window
- [ ] Cmd+, or gear button opens settings in a separate window
- [ ] Settings window reuses existing window if already open
- [ ] Warning threshold accepts values between 10-10000 MB
- [ ] Critical threshold accepts values between 50-50000 MB
- [ ] Scan interval accepts values between 5-300 seconds
- [ ] Stale days accepts values between 1-90 days
- [ ] Values outside valid ranges are clamped automatically
- [ ] Changing scan interval restarts the timer
- [ ] Notifications toggle enables/disables system notifications
- [ ] "Notifications are denied" warning appears when system permission is denied
- [ ] "Show size in menu bar" toggle shows/hides total size text next to menubar icon
- [ ] "Show size in menu bar" toggle persists after closing and reopening settings
- [ ] Toggling "Show size in menu bar" off immediately removes size text from menubar
- [ ] Toggling "Show size in menu bar" on immediately restores size text in menubar (when files exist)
- [ ] Launch at Login toggle registers/unregisters with SMAppService
- [ ] Settings changes persist after closing and reopening the window
- [ ] Settings window opens correctly after being closed and reopened

## Pluralization
- [ ] Status bar shows "1 file" (not "1 files") when exactly one file exists
- [ ] Project row shows "1 file" (not "1 files") when project has exactly one file

## Right-Click Menu
- [ ] Right-clicking the menubar icon shows a context menu
- [ ] Context menu contains "About Scumbag Claude", "Check for Updates...", and "Quit"
- [ ] "About Scumbag Claude" opens the About dialog
- [ ] "Check for Updates..." checks GitHub API and opens popover to show result
- [ ] "Quit" terminates the application

## About Dialog
- [ ] About dialog shows app icon
- [ ] About dialog shows "Scumbag Claude" title
- [ ] About dialog shows version number
- [ ] About dialog shows GitHub link
- [ ] Clicking GitHub link opens browser to the repository
- [ ] About dialog reuses existing window if already open
- [ ] About dialog opens correctly after being closed and reopened

## Keyboard Shortcuts
- [ ] Cmd+R refreshes the scan
- [ ] Cmd+, opens the settings window
- [ ] Cmd+Q quits the application

## Accessibility
- [ ] VoiceOver reads "Refresh" for the refresh button
- [ ] VoiceOver reads "Expand project" / "Collapse project" for chevron buttons
- [ ] VoiceOver reads "Delete project" for trash buttons
- [ ] VoiceOver reads "Delete file" for xmark buttons
- [ ] VoiceOver reads "Settings" for gear button
- [ ] Dot separators in status bar are hidden from VoiceOver
- [ ] Menubar label reads "Scumbag Claude status"

## Menubar Icon Color
- [ ] Menubar icon appears as system-tinted (template) icon in normal status (adapts to light/dark mode)
- [ ] Menubar icon turns orange when status changes to warning
- [ ] Menubar icon turns red when status changes to critical
- [ ] Menubar icon reverts to normal after deleting files that caused elevated status
- [ ] Orange and red icons remain their color regardless of light/dark mode
- [ ] If MenuBarIcon.png resource is missing, a fallback SF Symbol icon appears

## Footer Button Styling
- [ ] Settings, Clean All, Quit, and Confirm/Cancel buttons render as bordered macOS-native buttons (not plain text)
- [ ] Clean All button has orange tint
- [ ] Confirm button (for Clean All) has red tint
- [ ] Cancel button uses default system tint
- [ ] All footer buttons are small control size
- [ ] Footer buttons (bordered) visually contrast with inline project/file confirm/cancel buttons (plain) intentionally and consistently
- [ ] Footer does not overflow horizontally when Clean All confirmation buttons are visible alongside Settings and Quit

## Auto-Update
- [ ] On launch, auto-check triggers if enough time has passed since last check (24h default)
- [ ] "Check for Updates..." in right-click menu checks GitHub and shows result in popover
- [ ] When an update is available, blue-tinted banner appears between projects and footer
- [ ] "Update" button in banner starts download with progress bar
- [ ] "Cancel" button during download cancels and cleans up temp files
- [ ] After download completes, "Ready to install" banner appears with "Install & Restart" button
- [ ] Dismiss (X) button hides the banner and persists dismissed version across popover open/close
- [ ] Dismissed version does not re-show banner until a newer version is released
- [ ] When up to date (no newer release), popover shows ".upToDate" status briefly
- [ ] Network errors during manual check show error message with "Retry" button
- [ ] Network errors during automatic check fail silently (status stays .idle)
- [ ] "Check for updates automatically" toggle in Settings persists preference
- [ ] Disabling auto-check stops the periodic timer
- [ ] Re-enabling auto-check restarts the periodic timer
- [ ] About dialog shows "Update v{x.y.z} available" when update is available
- [ ] About dialog shows "Up to date" in green when up to date
- [ ] About dialog shows spinner + "Checking..." during check
- [ ] Running from dev build (swift run) shows "update manually" error instead of attempting install
- [ ] Install flow: app terminates, shell script replaces bundle, clears quarantine, relaunches

## FSEvents Detection
- [ ] Creating a new file in `/private/tmp/claude-*/` is detected within ~3 seconds (vs 15s poll)
- [ ] Deleting a file from `/private/tmp/claude-*/` is reflected in the popover within ~3 seconds
- [ ] File size growth at symlink targets in `~/.claude/projects/` triggers a scan within ~3 seconds
- [ ] Pie chart timer resets after an FSEvents-triggered scan
- [ ] Fallback timer still fires on schedule when no filesystem changes occur
- [ ] Manual refresh (Cmd+R) still works alongside FSEvents monitoring

## Growth Rate Tracking
- [ ] First scan shows no growth rate indicators (no prior data)
- [ ] Second scan shows "↑ X.X MB/min" on project row when files grew between scans
- [ ] Second scan shows "↑ X.X MB/min" on individual file rows for growing files
- [ ] Growth indicator disappears when a file stops growing (same size across scans)
- [ ] Project growth rate is the sum of its individual file growth rates
- [ ] Growth rate units scale appropriately (KB/min, MB/min, GB/min)

## Symlink Scope Indicators
- [ ] Symlinks with in-scope targets (under /private/tmp/claude-* or ~/.claude/projects/) show normal "→ filename" subtitle
- [ ] Symlinks with out-of-scope targets show "link only" purple pill badge next to the arrow subtitle
- [ ] Non-symlink files do not show any scope indicator
- [ ] Broken symlinks do not show a scope indicator (they show "broken symlink" in red instead)

## Deduplication Visibility
- [ ] Files with unique resolved paths show no duplicate badge
- [ ] When multiple symlinks point to the same resolved file, each shows a blue "×N" badge next to the filename
- [ ] Hovering the "×N" badge shows a tooltip explaining that size is counted once
- [ ] Broken symlinks are excluded from duplicate counting

## Broken Symlink Cleanup
- [ ] Project subtitle shows "N broken" count in red when project has broken symlinks
- [ ] Project subtitle omits broken count when project has no broken symlinks
- [ ] "Clean Broken (N)" button appears in footer when broken symlinks exist globally
- [ ] "Clean Broken (N)" button does not appear when no broken symlinks exist
- [ ] Clicking "Clean Broken" shows Cancel/Confirm buttons
- [ ] Confirming removes all broken symlinks across all projects
- [ ] After cleanup, broken count updates and button disappears if no broken symlinks remain
- [ ] Cleanup errors are shown in the footer as red text

## Statistics Window
- [ ] "Stats" button in footer opens the Statistics window
- [ ] "Statistics" in right-click menu opens the Statistics window
- [ ] Statistics window reuses existing window if already open
- [ ] Statistics window is resizable
- [ ] Time range picker switches between 1h, 24h, and 7d views
- [ ] Current/Peak/Average summary values update when range changes
- [ ] Chart shows area + line visualization of total size over time
- [ ] X-axis shows HH:mm for 1h and 24h ranges, abbreviated weekday for 7d
- [ ] Y-axis shows formatted byte values (KB, MB, GB)
- [ ] Empty state message appears when fewer than 2 data points exist
- [ ] After 2+ scans, chart populates with data points
- [ ] Data persists in `~/Library/Application Support/com.esison.claude-tmp-monitor/history.json`
- [ ] Quitting and relaunching preserves historical data in the chart
- [ ] Deleting history.json and relaunching shows empty state
- [ ] "History retention" setting in Settings accepts values between 1-30 days
- [ ] History retention setting persists after closing and reopening Settings
- [ ] Data older than retention period is pruned on save
- [ ] Changing retention to 1 day while 7 days of data is loaded prunes old data on the next save
- [ ] Data older than 1 hour is visibly coarser resolution (aggregated into 5-minute buckets)
- [ ] Statistics window chart and time range picker are accessible via VoiceOver

## Notifications
- [ ] Warning notification fires when a file crosses the warning threshold
- [ ] Critical notification fires when a file crosses the critical threshold
- [ ] Same file does not trigger duplicate notifications
- [ ] Notifications for deleted files are cleared from tracking
