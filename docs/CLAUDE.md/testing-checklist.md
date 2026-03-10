# Testing Checklist

## Core Functionality
- [ ] App launches as menubar icon (no Dock icon)
- [ ] Menubar shows icon and size text when tmp files exist
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

## Settings
- [ ] Cmd+, or gear button toggles settings panel
- [ ] Warning threshold accepts values between 10-10000 MB
- [ ] Critical threshold accepts values between 50-50000 MB
- [ ] Scan interval accepts values between 5-300 seconds
- [ ] Stale days accepts values between 1-90 days
- [ ] Values outside valid ranges are clamped automatically
- [ ] Changing scan interval restarts the timer
- [ ] Notifications toggle enables/disables system notifications
- [ ] "Notifications are denied" warning appears when system permission is denied
- [ ] Launch at Login toggle registers/unregisters with SMAppService

## Pluralization
- [ ] Status bar shows "1 file" (not "1 files") when exactly one file exists
- [ ] Project row shows "1 file" (not "1 files") when project has exactly one file

## Keyboard Shortcuts
- [ ] Cmd+R refreshes the scan
- [ ] Cmd+, toggles settings
- [ ] Cmd+Q quits the application

## Accessibility
- [ ] VoiceOver reads "Refresh" for the refresh button
- [ ] VoiceOver reads "Expand project" / "Collapse project" for chevron buttons
- [ ] VoiceOver reads "Delete project" for trash buttons
- [ ] VoiceOver reads "Delete file" for xmark buttons
- [ ] VoiceOver reads "Settings" for gear button
- [ ] Dot separators in status bar are hidden from VoiceOver
- [ ] Menubar label reads "Scumbag Claude status"

## Notifications
- [ ] Warning notification fires when a file crosses the warning threshold
- [ ] Critical notification fires when a file crosses the critical threshold
- [ ] Same file does not trigger duplicate notifications
- [ ] Notifications for deleted files are cleared from tracking
