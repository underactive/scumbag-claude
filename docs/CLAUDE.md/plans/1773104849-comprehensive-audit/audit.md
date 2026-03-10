# Comprehensive Audit Report: Scumbag Claude v0.1.0

**Date:** 2026-03-09
**Auditors:** 10 specialized subagents (UI/UX, Security, Performance, Accessibility, Localization, App Store Compliance, Data/Persistence, Networking, macOS API, Code Quality)

---

## Files Changed

All findings reference these files:

- `Sources/ClaudeTmpMonitor/App.swift`
- `Sources/ClaudeTmpMonitor/MonitorService.swift`
- `Sources/ClaudeTmpMonitor/ContentView.swift`
- `Package.swift`
- `Makefile`
- `Info.plist`

---

## Executive Summary

The app is a well-structured, zero-dependency macOS menubar utility with clean code and a solid architectural foundation. However, the audit identified **significant security vulnerabilities** (unrestricted symlink-following deletion), **zero accessibility support**, **no automated tests**, and several performance concerns for a long-running process. The app is not ready for distribution (no code signing or notarization), and App Store submission is architecturally infeasible.

### Finding Counts by Severity

| Severity | Count | Key Themes |
|----------|-------|------------|
| Blocker | 3 | No code signing, no entitlements, sandbox incompatibility |
| Critical | 9 | Arbitrary file deletion via symlinks, zero accessibility, deprecated API, potential crash on negative thresholds |
| High | 12 | Path traversal, no sandbox, no keyboard shortcuts, empty accessibility labels, missing tests, pluralization bugs |
| Medium | 18 | Silent error swallowing, unbounded memory growth, notification issues, UI layout, contrast, localization |
| Low | 16 | Timer tolerance, dead code, minor polish |
| Info | 20+ | Positive findings (good architecture, correct API usage, no networking) |

### Strengths

- Clean three-file architecture appropriate for project size
- Zero external dependencies (no supply chain risk)
- Correct use of `@MainActor`, `@StateObject`, value types
- Dark/light mode works correctly via semantic colors
- `ByteCountFormatter` and `.relative` date style are locale-aware
- Proper `isTemplate` menubar icon handling
- Build compiles cleanly with zero warnings

---

## 1. Security (SecurityAgent)

### Critical

**SEC-C1. Unrestricted symlink-following deletion allows arbitrary file deletion**
`MonitorService.swift:118-142` -- `deleteFile()` and `deleteProject()` delete the resolved target of symlinks without validating that the target resides within an expected directory. A symlink in `/private/tmp/claude-*/` pointing to `~/.ssh/id_rsa` would cause the app to delete the SSH key when the user clicks "Delete" or "Clean All."

*Remediation:* Add path validation allowlist before deleting symlink targets:
```swift
private func isInAllowedDeletionScope(_ path: String) -> Bool {
    let allowedPrefixes = ["/private/tmp/claude-", NSHomeDirectory() + "/.claude/projects/"]
    let resolved = (path as NSString).standardizingPath
    return allowedPrefixes.contains { resolved.hasPrefix($0) }
}
```

**SEC-C2. TOCTOU race condition between scan and delete**
`MonitorService.swift:118-128` -- The `MonitoredFile` struct captures `resolvedPath` at scan time. By the time the user clicks "Delete," the symlink's target could have been swapped.

*Remediation:* Re-resolve symlinks at deletion time and validate the resolved path is in allowed scope.

### High

**SEC-H1. No path validation on scanned directories**
`MonitorService.swift:159-207` -- A symlink named `claude-evil` in `/private/tmp/` pointing to `/etc` would pass the `hasPrefix("claude-")` check, causing the app to enumerate and expose arbitrary directory contents.

*Remediation:* Resolve the real path of `claudePath` and verify it is still under `/private/tmp/claude-`.

**SEC-H2. No App Sandbox -- full filesystem access**
No sandbox means all filesystem vulnerabilities are exploitable against the entire user filesystem.

### Medium

**SEC-M1. Silent error swallowing on delete operations** -- `MonitorService.swift:122,125,134,137` -- All `removeItem` calls use `try?`. If deletion fails, the user gets no feedback.

**SEC-M2. Unbounded growth of `notifiedPaths`** -- `MonitorService.swift:98` -- Set grows without pruning over weeks of runtime. Violates Development Rule 3.

**SEC-M3. Notification content from untrusted filesystem data** -- `MonitorService.swift:296-306` -- Crafted filenames could appear in system notifications for social engineering.

**SEC-M4. Relative symlink resolution uses wrong base directory** -- `MonitorService.swift:232-233` -- Relative symlinks resolved from the project root instead of the symlink's parent directory.

### Low

**SEC-L1. No range validation on UserDefaults load** -- `MonitorService.swift:100-107` -- `scanIntervalSeconds=0` causes tight polling loop; negative thresholds crash via `UInt64()` trap.

---

## 2. Performance (PerformanceAgent)

### High

**PERF-H1. Synchronous filesystem I/O on `@MainActor` blocks the main thread**
`MonitorService.swift:159-207` -- `scan()` does recursive directory traversal, stat calls, and symlink resolution synchronously on the main actor. Could cause UI jank during scans. The `isScanning` flag is set and cleared within a single synchronous frame, so the disabled state on the refresh button never renders.

*Remediation:* Move filesystem work to `Task.detached` and publish results back to `@MainActor`.

**PERF-H2. `notifiedPaths` grows without bound**
Same as SEC-M2. One-line fix: `notifiedPaths.formIntersection(currentPaths)` at end of scan.

### Medium

**PERF-M1. Menubar icon loaded from disk on every body evaluation** -- `App.swift:15-21` -- `menuBarImage` computed property re-creates NSImage every 30 seconds.

*Remediation:* Cache as `static let`.

**PERF-M2. "Clean All" triggers N sequential scan cycles** -- `ContentView.swift:326-330` -- Each `deleteProject` call triggers `scan()`. N projects = N redundant scans.

*Remediation:* Add a `deleteAllProjects()` batch method that scans once at the end.

**PERF-M3. Synchronous `scan()` during `init()` delays launch** -- `MonitorService.swift:100-112`

*Remediation:* Defer first scan to `Task { @MainActor in scan() }`.

---

## 3. UI/UX (UserInterfaceAgent)

### Critical

**UI-C1. Deprecated `.onChange(of:)` API** -- `ContentView.swift:288` -- Uses the macOS 13 single-parameter closure form, deprecated in macOS 14+. Produces compiler warnings on Xcode 15+.

**UI-C2. `confirmDelete` shared state collision** -- `ContentView.swift:9` -- Single `String?` used for project IDs, file IDs, and the literal `"all"`. If any path equals `"all"`, behavior collides.

*Remediation:* Use a typed enum: `enum DeleteConfirmation { case file(String), project(String), all }`.

### Warning

**UI-W1. ScrollView `maxHeight: 300` with no minimum** -- `ContentView.swift:123` -- Popover size jumps between small/large content.

**UI-W2. "Clean All" confirm button placement** -- `ContentView.swift:322-335` -- "Confirm" appears near "Quit", risking accidental clicks.

**UI-W3. No hover or focus indicators** -- All buttons use `.buttonStyle(.plain)` with no hover highlights.

**UI-W4. Tap target conflict on project rows** -- `ContentView.swift:186-187` -- `onTapGesture` on row conflicts with `.plain` buttons inside.

**UI-W5. Settings text fields accept values then clamp asynchronously** -- `ContentView.swift:284-291` -- Intermediate out-of-range values may be written to UserDefaults.

---

## 4. Accessibility (AccessibilityAgent)

### Critical

**A11Y-C1. No accessibility labels on any icon-only button** -- `ContentView.swift:46,129,177,245` -- VoiceOver announces SF Symbol names ("arrow.clockwise, button") instead of meaningful labels. Zero `.accessibilityLabel` modifiers exist in the entire codebase.

**A11Y-C2. Status indicator relies on color alone** -- `ContentView.swift:59-64` -- Green/orange/red circle with no shape/symbol differentiation. 8% of males cannot distinguish green from red.

**A11Y-C3. Delete confirmation state change invisible to VoiceOver** -- `ContentView.swift:163-182,231-250,322-335` -- Replacing trash icon with Cancel/Delete buttons produces no accessibility notification.

**A11Y-C4. Row `onTapGesture` inaccessible to VoiceOver** -- `ContentView.swift:187` -- VoiceOver users can only expand/collapse via the tiny chevron button.

### High

**A11Y-H1. No keyboard shortcuts for any action** -- Zero `.keyboardShortcut()` modifiers exist.

**A11Y-H2. Settings TextFields have empty accessibility labels** -- `ContentView.swift:284` -- `TextField("")` not programmatically associated with its visual label.

**A11Y-H3. "Stale" badge has no accessible description** -- `ContentView.swift:141-149`

### Medium

**A11Y-M1. `.secondary.opacity(0.6)` likely fails WCAG contrast** -- `ContentView.swift:102,218` -- Effective ~36% opacity of primary text.

**A11Y-M2. Fixed frame widths prevent Dynamic Type scaling** -- `ContentView.swift:33,132,286,295`

**A11Y-M3. MenuBar label lacks accessibility description** -- `App.swift:28-38`

---

## 5. App Store Compliance (AppStoreComplianceAgent)

### Blocker

**COMP-B1. No code signing configuration** -- Makefile never invokes `codesign`. Cannot notarize or distribute.

**COMP-B2. No entitlements file** -- Required for Hardened Runtime (notarization) and sandbox (App Store).

**COMP-B3. App Sandbox incompatible with architecture** -- App requires `/private/tmp/` and `~/.claude/` access, both outside sandbox. App Store submission is architecturally infeasible.

### Critical

**COMP-C1. No Hardened Runtime** -- Required for notarization.

**COMP-C2. Missing `NSPrincipalClass` in Info.plist** -- May cause initialization issues.

**COMP-C3. `NSUserNotificationAlertStyle` is deprecated** -- `Info.plist:26-27` -- Applies to legacy API, not `UNUserNotificationCenter`.

**COMP-C4. No notarization step in build pipeline**

**COMP-C5. SMAppService requires proper bundle and signing** -- Launch-at-login silently fails without code signing.

### Warning

**COMP-W1. Missing Privacy Manifest (PrivacyInfo.xcprivacy)** -- UserDefaults and file timestamp APIs require declarations.

**COMP-W2. Bundle missing `PkgInfo` file**

**COMP-W3. Nested resource bundle not independently signed** -- Will cause notarization failure.

---

## 6. Data & Persistence (CoreDataAgent)

### Critical

**DATA-C1. `UInt64(negativeInt)` traps on negative threshold values**
`MonitorService.swift:275-276` -- If `warningThresholdMB` or `criticalThresholdMB` is negative (via corrupted UserDefaults), `UInt64(negativeInt)` causes a fatal runtime trap, crashing the app on every scan cycle.

*Remediation:* Clamp values at load time: `max(10, min(10000, loaded))`.

### Warning

**DATA-W1. `launchAtLogin` `didSet` can trigger infinite recursion** -- `MonitorService.swift:80-93` -- If `SMAppService` consistently fails, revert triggers `didSet` again.

*Remediation:* Add re-entrancy guard flag.

**DATA-W2. `scanIntervalSeconds` `didSet` restarts timer on every keystroke** -- `MonitorService.swift:68-73`

*Remediation:* Add `guard scanIntervalSeconds != oldValue` check.

**DATA-W3. Unused `effectiveSize` and `isOutputFile` computed properties** -- `MonitorService.swift:17,19-21` -- Dead code.

**DATA-W4. No migration path for UserDefaults keys** -- Raw string literals used in multiple places.

*Remediation:* Extract key names to constants enum.

---

## 7. macOS API Best Practices (macOSAPIAgent)

### Warning

**API-W1. Path-based FileManager APIs are legacy** -- `MonitorService.swift` -- URL-based APIs with `includingPropertiesForKeys` would prefetch attributes in a single syscall per entry, eliminating redundant `attributesOfItem` calls.

**API-W2. Timer RunLoop mode pauses during UI tracking** -- `MonitorService.swift:148` -- `.default` mode timers don't fire while user is scrolling/dragging. Acceptable but worth documenting.

**API-W3. Notification authorization result ignored** -- `MonitorService.swift:333` -- `notificationsEnabled` toggle may show `true` while system has denied permissions.

**API-W4. No `deinit` timer invalidation** -- `MonitorService.swift` -- Timer never invalidated if service is deallocated.

---

## 8. Localization (LocalizationAgent)

### High

**L10N-H1. Pluralization is incorrect even in English** -- `ContentView.swift:71,151` -- Displays "1 files" when there is exactly one file.

*Remediation:* `"\(count) \(count == 1 ? "file" : "files")"`.

**L10N-H2. `MonitorStatus.rawValue` used as display string** -- `MonitorService.swift:37-39` -- Enum raw values cannot be localized.

### Medium

**L10N-M1. All 30+ UI strings hardcoded without extraction** -- No `.strings` or String Catalog files.

**L10N-M2. Unit labels "sec"/"days" are English-only** -- `ContentView.swift:264-267`

---

## 9. Code Quality (CodeQualityAgent)

### Critical

**CQ-C1. No automated tests exist** -- No test target in `Package.swift`. `extractProjectName()` and `formatBytes()` are the highest-value, most testable targets.

### Warning

**CQ-W1. Threshold byte calculation duplicated in 3 places** -- `MonitorService.swift:275-276`, `ContentView.swift:359-360`

*Remediation:* Add `warningBytes`/`criticalBytes` computed properties to `MonitorService`.

**CQ-W2. No linter configured**

**CQ-W3. No CI/CD pipeline**

**CQ-W4. Confirm/cancel button pattern duplicated** -- `ContentView.swift:163-182` and `231-250`

---

## 10. Networking (NetworkingAgent)

**No findings.** The app has zero networking code. All five findings are informational:
- No networking confirmed across all files
- No `NSAppTransportSecurity` needed
- No auto-update mechanism (acceptable for v0.1.0)
- No telemetry (correct posture for this app)
- `UNUserNotificationCenter` and `SMAppService` are local-only

---

## Priority Remediation Roadmap

### P0 -- Fix Before Any Use (Security + Crash)

1. **SEC-C1 + SEC-H1** -- Add symlink target path validation allowlist for both scanning and deletion
2. **SEC-M4** -- Fix relative symlink resolution to use symlink's parent directory
3. **DATA-C1 + SEC-L1** -- Clamp all UserDefaults values at load time (prevents crash + CPU pegging)
4. **DATA-W1** -- Add re-entrancy guard to `launchAtLogin` `didSet`

### P1 -- Fix Before Distribution

5. **COMP-B1/C1/C4** -- Add code signing, hardened runtime, and notarization to Makefile
6. **COMP-B2** -- Create entitlements file
7. **COMP-C2/C3** -- Fix Info.plist (add `NSPrincipalClass`, remove deprecated key)
8. **SEC-M2 / PERF-H2** -- Prune `notifiedPaths` at end of each scan (one-line fix)
9. **SEC-M1** -- Surface deletion errors to user

### P2 -- Quality Improvements

10. **PERF-H1** -- Move scan I/O off main thread (async refactor)
11. **PERF-M1** -- Cache menubar icon as `static let`
12. **UI-C1** -- Update deprecated `.onChange(of:)` API
13. **UI-C2** -- Replace `confirmDelete: String?` with typed enum
14. **L10N-H1** -- Fix "1 files" pluralization
15. **CQ-C1** -- Add test target with tests for `extractProjectName` and `formatBytes`
16. **CQ-W1** -- Extract threshold byte computation into computed properties
17. **PERF-M2** -- Add batch `deleteAllProjects()` method

### P3 -- Accessibility (Comprehensive Pass)

18. **A11Y-C1** -- Add `.accessibilityLabel` to all icon-only buttons
19. **A11Y-C2** -- Add shape/symbol differentiation to status indicator
20. **A11Y-C3** -- Post accessibility notifications on confirm/delete state changes
21. **A11Y-C4** -- Add accessibility actions for row expand/collapse
22. **A11Y-H1** -- Add keyboard shortcuts (Cmd+R scan, Cmd+Q quit, Cmd+, settings)
23. **A11Y-H2** -- Associate TextField labels programmatically
24. **A11Y-M1** -- Remove `.opacity(0.6)` on secondary text

### P4 -- Polish & Long-Term

25. **API-W1** -- Migrate to URL-based FileManager APIs
26. **CQ-W2/W3** -- Add SwiftLint and CI pipeline
27. **COMP-W1** -- Add Privacy Manifest
28. **DATA-W4** -- Extract UserDefaults keys to constants enum
29. **L10N-M1** -- Extract strings for localization readiness
30. **DATA-W3** -- Remove or use dead `effectiveSize`/`isOutputFile` properties
