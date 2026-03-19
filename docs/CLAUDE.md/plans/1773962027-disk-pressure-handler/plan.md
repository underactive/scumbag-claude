# Plan: Disk Pressure Handler

## Objective

Add system-level disk space monitoring to Scumbag Claude. The app already tracks Claude tmp file sizes, but has no awareness of actual disk pressure. This feature polls available disk space during each scan cycle via `URL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])` — an APFS-aware API — and surfaces a cleanup prompt when free space drops below a configurable threshold.

## Changes

### MonitorService.swift
- Add `diskPressureEnabled` and `diskPressureThresholdGB` to `SettingsKey` enum
- Add `@Published` properties: `diskPressureDetected`, `availableDiskSpaceGB`, `diskPressureEnabled`, `diskPressureThresholdGB`
- Add private `diskPressureNotified` for episode-based notification dedup
- Load settings in `init()` with existing pattern
- Add `checkDiskPressure()` method called from `scan()` after `updateStatus()`
- Episode-based notification: fires once per transition into pressure, resets on recovery

### ContentView.swift
- Add `diskPressureBannerSection` computed property with orange-toned banner
- Insert between projects and update banner in body layout

### SettingsView.swift
- Add toggle and conditional threshold row in General tab after history retention

### CLAUDE.md
- Document new settings and disk pressure handler in architecture sections

## Dependencies

No ordering constraints beyond the listed implementation order. All changes are additive.

## Risks / open questions

- No hysteresis at the boundary — banner may flicker if disk space oscillates near threshold. Notification dedup prevents spam. Can add 500 MB buffer later if flapping observed.
- `volumeAvailableCapacityForImportantUsageKey` requires macOS 11+; project targets macOS 13 so this is safe.
