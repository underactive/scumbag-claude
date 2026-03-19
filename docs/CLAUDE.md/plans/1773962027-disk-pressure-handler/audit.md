# Audit Report: Disk Pressure Handler

## Files changed

- `Sources/ClaudeTmpMonitor/MonitorService.swift`
- `Sources/ClaudeTmpMonitor/ContentView.swift`
- `Sources/ClaudeTmpMonitor/SettingsView.swift`

---

## 1. QA Audit

| # | Severity | Finding |
|---|----------|---------|
| QA-1 | Low | Toggling `diskPressureEnabled` off resets `diskPressureNotified`, causing spurious repeat notification on re-enable — accepted as intentional "new episode" behavior per spec |
| QA-2 | Medium | [FIXED] `diskPressureNotified = true` was set even when `notificationsEnabled = false`, preventing notification delivery if notifications re-enabled during same pressure episode. Fixed by gating on `notificationsEnabled`. |
| QA-3 | Low | `diskPressureEnabled` defaults to `true` — deliberate, consistent with `notificationsEnabled` default |
| QA-5 | Very Low | Three `@Published` assignments fire on every scan when feature is disabled — accepted, negligible cost |
| QA-7 | Low/UX | Banner has no dismiss button — intentional per plan (clears naturally on recovery) |

## 2. Security Audit

| # | Severity | Finding |
|---|----------|---------|
| SEC-1 | Low | [FIXED] `diskPressureNotified` was set after `sendNotification()`, leaving re-entrancy window. Reordered to set flag before sending. |
| SEC-2 | Low | Toggle-off during pressure clears `diskPressureNotified` — accepted per "new episode" spec |
| SEC-3 | Info | `Double(Int64)` promotion for bytes-to-GB — safe on all real hardware |
| SEC-4 | Info | `didSet` single-recursion clamp — bounded, matches existing pattern |
| SEC-5 | None | No format string injection in banner — system-derived data only |
| SEC-6 | UX | No dismiss button — by design |
| SEC-7 | UX | Stored threshold not visible when toggle off — accepted, consistent with watchdog tabs |

## 3. Interface Contract Audit

| # | Severity | Finding |
|---|----------|---------|
| IC-1 | Medium | `diskPressureNotified` reset on disable allows re-notification on re-enable — accepted as "new episode" |
| IC-2 | Low | `diskPressureDetected` used as both UI state and edge-trigger input — accepted, single-writer `@MainActor` prevents races |
| IC-3 | Medium | Transient API failure clears active banner — accepted as fail-open behavior; low probability on macOS |
| IC-4 | Low | Double `@Published` emission on out-of-range clamp — matches existing pattern across all settings |
| IC-5 | Low | [FIXED] `NSHomeDirectory()` vs `FileManager.default.homeDirectoryForCurrentUser` inconsistency. Changed to use `FileManager` for consistency. |

## 4. State Management Audit

| # | Severity | Finding |
|---|----------|---------|
| SM-1 | Low | `availableDiskSpaceGB` not cleared on pressure recovery — accepted, banner gates on `diskPressureDetected` |
| SM-2 | Low | Double `@Published` notification on out-of-range threshold — matches existing pattern |
| SM-3 | Low | Banner state change fires while `isScanning == true` — no current consumer reads both |
| SM-4 | Low | Two separate published properties as implicit unit — accepted, adding a struct would be over-engineering |
| SM-5 | Medium | [FIXED] Disabling toggle left banner visible until next scan. Fixed by clearing state in `diskPressureEnabled` `didSet`. |

## 5. Resource & Concurrency Audit

| # | Severity | Finding |
|---|----------|---------|
| RC-1 | Medium | `didSet` recursion in threshold — terminates correctly, matches established pattern |
| RC-2 | Low | Duplicate notification after toggle cycle — accepted as "new episode" per spec |
| RC-3 | Low | Synchronous `resourceValues` on main actor — marginal cost vs existing scan I/O |
| RC-6 | Pass | Concurrency isolation correct throughout — all mutations on `@MainActor` |

## 6. Testing Coverage Audit

| # | Severity | Finding |
|---|----------|---------|
| TC-1 | Medium | [FIXED] Missing checklist: notifications disabled during pressure. Added to testing checklist. |
| TC-2 | Low | [FIXED] Missing checklist: simultaneous banners. Added. |
| TC-3 | Low | [FIXED] Missing checklist: toggle off+on re-notification. Added. |
| TC-4 | Low | [FIXED] Missing checklist: exact threshold boundary. Added. |
| TC-5 | Low | [FIXED] Missing checklist: clamped value persistence after relaunch. Added. |
| TC-7 | Low | [FIXED] Missing checklist: rapid FSEvents single notification. Added. |

## 7. DX & Maintainability Audit

| # | Severity | Finding |
|---|----------|---------|
| DX-1 | Low | Missing WHY comment on re-arm behavior — accepted, behavior is consistent with plan spec |
| DX-2 | Low | Magic number `1024 * 1024 * 1024` — clear in context (bytes to GB), named constant would be over-engineering for one use site |
| DX-3 | Low | Optional invariant undocumented (`availableDiskSpaceGB` non-nil iff `diskPressureDetected`) — accepted |
| DX-4 | Low | Implicit call-order dependency in `scan()` — accepted, same pattern as existing `updateStatus()` |
| DX-5 | Low | Banner ordering rationale absent — disk pressure more urgent than update, reasonable default |
| DX-6 | Medium | [FIXED] Notification body said "Claude tmp files" but banner said "Claude tmp". Aligned banner to match. |
| DX-7 | Info | No animation on conditional threshold row — consistent with existing tabs |
| DX-8 | Info | Silent clamp on out-of-range input — inherited from existing `settingRow` pattern |

---

## Summary of fixes applied

1. **[SEC-1]** Reordered `diskPressureNotified = true` before `sendNotification()` call
2. **[QA-2]** Added `&& notificationsEnabled` guard so `diskPressureNotified` is only set when notification actually delivered
3. **[SM-5]** Added state cleanup in `diskPressureEnabled` `didSet` for immediate banner dismissal on toggle-off
4. **[IC-5]** Changed `NSHomeDirectory()` to `FileManager.default.homeDirectoryForCurrentUser` for API consistency
5. **[DX-6]** Aligned banner subtitle string to match notification body ("Claude tmp files")
6. **[TC-*]** Added 7 testing checklist items covering edge cases and integration paths

## Unresolved items

- **QA-1/IC-1/RC-2**: Toggle-off resets `diskPressureNotified` — intentional per plan spec, each disable/enable cycle is a new episode
- **QA-7/SEC-6**: No dismiss button on banner — by design, clears naturally on recovery
- **IC-3**: Transient API failure clears active banner — accepted as fail-open
- **DX-2**: Inline bytes-to-GB literal — acceptable for single use site
