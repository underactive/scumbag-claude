# Audit: Settings Dialog + Right-Click About Menu

## Files Changed

- `Sources/ClaudeTmpMonitor/App.swift`
- `Sources/ClaudeTmpMonitor/ContentView.swift`
- `Sources/ClaudeTmpMonitor/SettingsView.swift`
- `Sources/ClaudeTmpMonitor/AboutView.swift`
- `Sources/ClaudeTmpMonitor/MonitorService.swift` (immediate dependent)
- `docs/CLAUDE.md/testing-checklist.md`

---

## 1. QA Audit

| # | Finding | File | Lines | Severity |
|---|---------|------|-------|----------|
| QA-1 | [FIXED] Right-click menu set/performClick/nil pattern relies on synchronous AppKit menu tracking | App.swift | 109-112 | Low |
| QA-2 | Popover contentViewController created once at launch — acceptable for singleton lifecycle | App.swift | 75-78 | Low |
| QA-3 | [FIXED] Redundant `.receive(on: RunLoop.main)` adds one-tick delay | App.swift | 95-100 | Low |
| QA-4 | Static `baseImage` could be nil if resource missing — severe failure mode (invisible icon) | App.swift | 19-24 | Low |
| QA-5 | [FIXED] Fixed popover contentSize may clip — mitigated by internal ScrollView | App.swift | 74 | Low |
| QA-6 | [FIXED] Settings/About windows recreated on each open after close | App.swift | 139-184 | Medium |
| QA-7 | `onOpenSettings` default empty closure makes wiring failures silent | ContentView.swift | 17 | Low |
| QA-8 | `onTapGesture` on project row may conflict with child buttons (known SwiftUI quirk) | ContentView.swift | 195 | Low |
| QA-9 | No validation that warning threshold < critical threshold (pre-existing) | SettingsView.swift | — | Low |

## 2. Security Audit

| # | Finding | File | Lines | Severity |
|---|---------|------|-------|----------|
| SEC-1 | [FIXED] Force-unwrapped URL literal in AboutView | AboutView.swift | 23 | Low |
| SEC-2 | Popover hosting controller lifetime tied to process — no leak | App.swift | 72-78 | Low |
| SEC-3 | [FIXED] Settings/About windows: `isVisible` check should be existence check | App.swift | 139-184 | Medium |
| SEC-4 | Right-click menu set/nil race — actually safe due to synchronous menu tracking | App.swift | 110-112 | Low |
| SEC-5 | TextField input unvalidated at view layer — mitigated by didSet clamping | SettingsView.swift | 41-44 | Low |
| SEC-6 | UInt64 multiplication overflow — already mitigated by clamped ranges | MonitorService.swift | 120-121 | None |
| SEC-7 | Implicitly unwrapped optionals for statusItem/popover — safe given init ordering | App.swift | 7-9 | Low |

## 3. Interface Contract Audit

| # | Finding | File | Lines | Severity |
|---|---------|------|-------|----------|
| IC-1 | `Bundle.main` may not contain `Info.plist` outside `.app` bundle — fallback to "Unknown" | AboutView.swift | 5 | Medium |
| IC-2 | Right-click menu set-click-clear relies on undocumented AppKit retain behavior | App.swift | 110-112 | Low |
| IC-3 | [FIXED] `confirmDelete` state persists across popover close/reopen — stale UI | ContentView.swift | 16 | Medium |
| IC-4 | `expandedProjects` set grows unbounded with stale project IDs | ContentView.swift | 15 | Low |
| IC-5 | [FIXED] Closed-but-not-released settings/about windows leak on reopen | App.swift | 139-184 | Low |
| IC-6 | `launchAtLogin` toggle error silently swallowed — no user feedback (pre-existing) | MonitorService.swift | 101-116 | Low |

## 4. State Management Audit

| # | Finding | File | Lines | Severity |
|---|---------|------|-------|----------|
| SM-1 | MonitorService ownership moved from SwiftUI `@StateObject` to plain property — double-instantiation risk unlikely but latent | App.swift | 10 | Medium |
| SM-2 | [FIXED] Redundant `.receive(on: RunLoop.main)` introduces one-tick delay | App.swift | 95-100 | Low |
| SM-3 | Popover root view created once, closure environment baked in — acceptable for singleton | App.swift | 75-78 | Low |
| SM-4 | [FIXED] Settings/About windows leak on reopen (isVisible vs existence check) | App.swift | 139-184 | Medium |
| SM-5 | TextField clamping on every keystroke causes UX jitter (pre-existing) | SettingsView.swift | — | Info |
| SM-6 | No-op default closure on `onOpenSettings` makes wiring failures silent | ContentView.swift | 17 | Low |

## 5. Resource & Concurrency Audit

| # | Finding | File | Lines | Severity |
|---|---------|------|-------|----------|
| RC-1 | Right-click menu nil-after-performClick relies on synchronous menu tracking | App.swift | 109-112 | Low |
| RC-2 | [FIXED] Settings/About old hosting controllers not torn down on reopen | App.swift | 139-184 | Low |
| RC-3 | Popover hosting controller keeps SwiftUI hierarchy alive when hidden — by design | App.swift | 72-78 | Info |
| RC-4 | [FIXED] Redundant `receive(on: RunLoop.main)` | App.swift | 95-100 | Low |
| RC-5 | Timer creates unbounded Task queue if scan exceeds interval — mitigated by isScanning guard | MonitorService.swift | 268-271 | Low |
| RC-6 | `deinit` timer invalidation is dead code for app-lifetime service | MonitorService.swift | 154-156 | Info |

## 6. Testing Coverage Audit

| # | Finding | File | Lines | Severity |
|---|---------|------|-------|----------|
| TC-1 | [FIXED] No checklist items for left-click popover open/close/dismiss | — | — | Medium |
| TC-2 | [FIXED] No check for empty menubar title when no files exist | — | — | Low |
| TC-3 | [FIXED] Stale checklist item: "fallback SF Symbol icon" behavior was missing from code | App.swift | 47-57 | High |
| TC-4 | [FIXED] No close-and-reopen test for settings/about windows | — | — | Medium |
| TC-5 | [FIXED] No check for reactive/automatic menubar updates after background scan | — | — | Medium |
| TC-6 | About dialog shows "Unknown" version when running without app bundle — acceptable | AboutView.swift | 4-6 | Low |

## 7. DX & Maintainability Audit

| # | Finding | File | Lines | Severity |
|---|---------|------|-------|----------|
| DX-1 | [FIXED] Dead code: `MonitorStatus.iconName` and `MonitorService.statusIcon` unused | MonitorService.swift | 45-51, 118 | Low |
| DX-2 | [FIXED] Dead code: unused `projectDisplayName` parameter in `fileRow` | ContentView.swift | 201, 207 | Low |
| DX-3 | Duplicated window creation logic in `openSettings` / `showAbout` | App.swift | 139-184 | Low |
| DX-4 | Magic number `380` duplicated across App.swift and ContentView.swift | App.swift, ContentView.swift | 74, 35 | Low |
| DX-5 | Non-obvious `statusItem.menu = nil` workaround — existing comment adequate | App.swift | 109-112 | Low |
| DX-6 | `Bundle.main` returns "Unknown" version outside `.app` bundle — no explanatory comment | AboutView.swift | 4-6 | Low |

---

## Summary

**Total findings:** 42 across 7 audits
**Fixed:** 14 findings addressed
**Deferred (pre-existing / accepted):** Remaining low/info findings are either pre-existing patterns, by-design behavior, or low-risk items not worth addressing for the current codebase size.

### Key fixes applied:
1. Settings/About windows now reuse existing instances instead of recreating (SEC-3, SM-4, RC-2, QA-6)
2. Force-unwrapped URL replaced with static let + guard (SEC-1)
3. Redundant `.receive(on: RunLoop.main)` removed from Combine pipeline (QA-3, SM-2, RC-4)
4. `confirmDelete` state reset on popover appear (IC-3)
5. Dead code removed: `iconName`, `statusIcon`, unused `projectDisplayName` parameter (DX-1, DX-2)
6. Fallback SF Symbol icon added when resource image is missing (TC-3)
7. Testing checklist updated with missing items for popover, window lifecycle, reactive updates (TC-1, TC-2, TC-4, TC-5)
