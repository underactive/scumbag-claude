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
- [ ] Launch at Login toggle registers/unregisters with SMAppService
- [ ] Settings changes persist after closing and reopening the window
- [ ] Settings window opens correctly after being closed and reopened

## Pluralization
- [ ] Status bar shows "1 file" (not "1 files") when exactly one file exists
- [ ] Project row shows "1 file" (not "1 files") when project has exactly one file

## Right-Click Menu
- [ ] Right-clicking the menubar icon shows a context menu
- [ ] Context menu contains "About Scumbag Claude" and "Quit"
- [ ] "About Scumbag Claude" opens the About dialog
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

## Notifications
- [ ] Warning notification fires when a file crosses the warning threshold
- [ ] Critical notification fires when a file crosses the critical threshold
- [ ] Same file does not trigger duplicate notifications
- [ ] Notifications for deleted files are cleared from tracking
