# Implementation: Disk Pressure Handler

## Files changed

- `Sources/ClaudeTmpMonitor/MonitorService.swift` — Added settings keys, published properties, init loading, `checkDiskPressure()` method, scan integration
- `Sources/ClaudeTmpMonitor/ContentView.swift` — Added `diskPressureBannerSection` orange banner between projects and update banner
- `Sources/ClaudeTmpMonitor/SettingsView.swift` — Added disk pressure toggle and conditional threshold row in General tab
- `CLAUDE.md` — Updated settings section, architecture descriptions for MonitorService/ContentView/SettingsView, added disk pressure detection subsection

## Summary

Implemented as planned with no deviations. The disk pressure handler:

1. **MonitorService** gains two new settings (`diskPressureEnabled`, `diskPressureThresholdGB`) with standard UserDefaults persistence and clamping. `checkDiskPressure()` queries APFS-aware available space via `volumeAvailableCapacityForImportantUsageKey`, publishes `diskPressureDetected` and `availableDiskSpaceGB`, and uses episode-based notification dedup (`diskPressureNotified` boolean that resets on pressure recovery).

2. **ContentView** adds an orange banner with `externaldrive.badge.exclamationmark` icon showing free space and Claude tmp usage. Banner appears/disappears automatically based on `diskPressureDetected`.

3. **SettingsView** adds a toggle and conditional threshold field in the General tab, between history retention and the show-size-in-menubar toggle.

## Verification

- `make build` (release) — clean compilation, no warnings
- Code review of all changes against plan specification — all items implemented

## Follow-ups

- No hysteresis buffer — if disk space oscillates near threshold, banner may flicker. Notification dedup prevents spam. Can add 500 MB buffer if flapping is observed.

## Audit Fixes

### Fixes applied

1. **[SEC-1]** Reordered `diskPressureNotified = true` before `sendNotification()` to close re-entrancy window (Security Audit Finding 1)
2. **[QA-2]** Added `&& notificationsEnabled` guard so `diskPressureNotified` is only set when notification is actually delivered — re-enabling notifications during pressure now fires the deferred notification (QA Audit Finding 2)
3. **[SM-5]** Added state cleanup (`diskPressureDetected`, `availableDiskSpaceGB`, `diskPressureNotified`) in `diskPressureEnabled` `didSet` for immediate banner dismissal on toggle-off (State Management Audit Finding 5)
4. **[IC-5]** Changed `NSHomeDirectory()` to `FileManager.default.homeDirectoryForCurrentUser` for API consistency with `isInAllowedDeletionScope()` (Interface Contract Audit Finding 5)
5. **[DX-6]** Aligned banner subtitle string to match notification body — both now say "Claude tmp files" (DX Audit Finding 6)
6. **[TC-*]** Added 7 testing checklist items covering: notifications-disabled interaction, toggle off+on re-notification, exact threshold boundary, simultaneous banners, clamped value persistence, and rapid FSEvents single notification (Testing Coverage Audit gaps 1–7)

### Verification checklist

- [x] Verify `diskPressureNotified` is set before `sendNotification()` call
- [x] Verify `notificationsEnabled` guard prevents `diskPressureNotified` from being set when notifications are off
- [x] Verify `diskPressureEnabled` `didSet` immediately clears `diskPressureDetected`, `availableDiskSpaceGB`, and `diskPressureNotified`
- [x] Verify `checkDiskPressure()` uses `FileManager.default.homeDirectoryForCurrentUser` (not `NSHomeDirectory()`)
- [x] Verify banner and notification body both say "Claude tmp files"
- [x] Verify `make build` passes after all fixes
- [x] Verify testing checklist includes all 7 new items
