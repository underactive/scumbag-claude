# CLAUDE.md - Scumbag Claude Project Context

## Project Overview

**Scumbag Claude** (aka Claude Tmp Monitor) is a macOS menubar application that monitors Claude Code's temporary file directories (`/private/tmp/claude-*/`) for large `.output` files and stale task directories, alerting the user and providing quick cleanup actions.

**Current Version:** 0.4.0
**Status:** In development

---

## Hardware

Not applicable — this is a software-only macOS application.

---

## Architecture

### Core Files
Eight-file SwiftUI app using a custom `NSStatusItem` for menubar integration.

- `Sources/ClaudeTmpMonitor/App.swift` - Entry point: `@main` SwiftUI App with `NSApplicationDelegateAdaptor`. `AppDelegate` owns `MonitorService`, `UpdateService`, and `HistoryService`, creates `NSStatusItem` with `NSPopover` (left-click) and `NSMenu` (right-click). Manages singleton `NSWindow` instances for Settings, About, and Statistics dialogs. Uses `Combine` subscriber on `monitor.$status` + `monitor.$totalSize` to reactively update menubar icon and title. Wires `monitor.onScanComplete` callback to `HistoryService.recordSnapshot()`. Flushes history on `applicationWillTerminate`. Loads menubar icon from `Bundle.module` resources.
- `Sources/ClaudeTmpMonitor/MonitorService.swift` - Core business logic: models (`MonitoredFile`, `ClaudeProject`, `MonitorStatus`), FSEvents + timer-based scanning, growth rate tracking, symlink scope/deduplication visibility, settings persistence, notifications, deletion. Exposes `onScanComplete` callback invoked at the end of each `scan()`.
- `Sources/ClaudeTmpMonitor/HistoryService.swift` - Historical data persistence: records scan snapshots (`HistorySnapshot`, `ProjectSnapshot` Codable models), two-tier aggregation (raw ≤1h, 5-minute buckets beyond), JSON storage in `~/Library/Application Support/com.esison.claude-tmp-monitor/history.json`, configurable retention (1–30 days), 60s save timer, querying by `TimeRange`.
- `Sources/ClaudeTmpMonitor/UpdateService.swift` - Auto-update logic: GitHub releases API checking, download with progress, self-replacement via shell script, version comparison. Persists settings via UserDefaults.
- `Sources/ClaudeTmpMonitor/ContentView.swift` - Main popover view: header, status bar, expandable projects list with symlink scope/deduplication badges and broken symlink counts, update banner, footer with Settings button, Stats button, Clean Broken, Clean All, and Quit. Receives `onOpenSettings` and `onOpenStats` closures from `AppDelegate`. Defines `HoverButtonStyle` (custom `ButtonStyle` with configurable hover color) used by icon-only buttons.
- `Sources/ClaudeTmpMonitor/StatsView.swift` - Statistics window: SwiftUI Charts area+line chart of total size over time, segmented time range picker (1h/24h/7d), current/peak/average summary stats, empty state. Hosted in a separate resizable `NSWindow`.
- `Sources/ClaudeTmpMonitor/SettingsView.swift` - Settings dialog: threshold/interval rows, history retention row, notifications toggle, launch at login toggle. Hosted in a separate `NSWindow`.
- `Sources/ClaudeTmpMonitor/AboutView.swift` - About dialog: app icon, name, version, update status, GitHub link. Hosted in a separate `NSWindow`.

### Dependencies
- SwiftUI (views, `NSHostingController` for window content)
- Foundation (`FileManager` for directory scanning, `Timer` for polling)
- UserNotifications (`UNUserNotificationCenter` for system alerts)
- AppKit (`NSStatusItem`, `NSPopover`, `NSMenu`, `NSWindow`, `NSImage` for menubar integration)
- Combine (`combineLatest`, `sink` for reactive menubar icon updates)
- ServiceManagement (`SMAppService` for launch-at-login)
- CoreServices (`FSEventStream` for filesystem change notifications)
- Charts (SwiftUI Charts framework for `AreaMark`, `LineMark`, `AxisMarks` in statistics view)
- URLSession (async `data(from:)` and `download(from:)` for GitHub API and update downloads)

### Key Subsystems

#### 1. File Monitoring (MonitorService.scan)
- **Primary: FSEvents** — watches `/private/tmp` and `~/.claude/projects/` via `FSEventStreamCreate` for near-instant detection (~2.5s worst case). Callback filters events for paths containing `/claude-` or `/.claude/projects/`, debounces with 0.5s delay, then triggers a scan. Watches `/private/tmp` (parent) because `claude-*` dirs may not exist at startup.
- **Fallback: Timer** — polls every N seconds (default 15) as a safety net. Timer resets after every scan regardless of trigger source (FSEvents, timer, or manual).
- Enumerates all subdirectories and files recursively via `FileManager.enumerator`
- Resolves symlinks to get actual file sizes; detects and handles broken symlinks
- Deduplicates by resolved path (`seenResolvedPaths: Set<String>`) to avoid double-counting
- Monitored directory structure:
```
/private/tmp/claude-{uid}/
  {project-path}/           # e.g., -Users-esison-Development-personal-LeadProspector
    tasks/
      {taskid}.output       # Symlink to .jsonl OR actual large file
```
- `.output` files may be symlinks to `~/.claude/projects/.../subagents/agent-*.jsonl` or actual files that grow unbounded
- **Growth rate tracking**: Compares file sizes across successive scans via `previousSizes: [String: (size: UInt64, time: Date)]` (keyed by resolved path). Computes `growthRate` (bytes/sec) per file; `ClaudeProject.growthRate` is the sum of its files' rates. UI shows "↑ X.X MB/min" indicators on project and file rows for actively growing files. `formatGrowthRate()` converts bytes/sec to KB/min, MB/min, or GB/min.
- **Symlink scope visibility**: Each `MonitoredFile` has `isTargetInScope: Bool` indicating whether its symlink target is within the allowed deletion scope (`/private/tmp/claude-*` or `~/.claude/projects/`). Non-symlinks and broken symlinks are always in scope. Out-of-scope symlinks show a "link only" pill badge in the UI, indicating that deletion removes only the symlink entry, not the target file.
- **Deduplication visibility**: After scanning all projects, `scan()` builds a global `resolvedPath → count` frequency map. Files sharing the same resolved path get `duplicateCount > 1`. The UI shows a "×N" badge in blue when multiple symlinks point to the same target, with a tooltip explaining that size is counted once.
- **Broken symlink cleanup**: `ClaudeProject.brokenSymlinkCount` counts broken symlinks per project (shown in subtitle). `deleteBrokenSymlinks()` removes all broken symlink entries globally. `deleteBrokenSymlinksInProject(_:)` scopes cleanup to a single project. The footer shows a "Clean Broken (N)" button when broken symlinks exist.

#### 2. History & Statistics (HistoryService)
- `HistoryService` records a `HistorySnapshot` after each scan via `MonitorService.onScanComplete` callback
- **Two-tier aggregation**: raw scan-resolution snapshots kept for ≤1 hour; older data downsampled to 5-minute buckets (averaging totalSize, totalFileCount, per-project values). Steady-state: ~2,256 records, <500 KB.
- **Persistence**: JSON-encoded to `~/Library/Application Support/com.esison.claude-tmp-monitor/history.json`. Save runs every 60s + on `applicationWillTerminate`. Load on init.
- **Retention**: configurable 1–30 days (default 7) via `historyRetentionDays`. Pruning runs at each save.
- **Querying**: `snapshots(for:)` filters by `TimeRange` (.oneHour, .twentyFourHours, .sevenDays); `peakSize(in:)` and `averageSize(in:)` compute stats.
- **StatsView**: Separate 600×450 resizable `NSWindow` with SwiftUI Charts `AreaMark`+`LineMark`, segmented time range picker, current/peak/average summary row, and empty state for <2 data points.

#### 3. Status & Notifications
- Three states: Normal (green), Warning (orange), Critical (red)
- Status determined by largest individual file size OR total size vs thresholds
- Tracks `notifiedPaths: Set<String>` — each file triggers a system notification only once per threshold crossing
- Menubar icon changes color to reflect current status (via Combine subscriber)

#### 4. Settings / Configuration Storage
```swift
warningThresholdMB: Int     // default: 100, range: 10...1000000
criticalThresholdMB: Int    // default: 500, range: 50...1000000
scanIntervalSeconds: Int    // default: 15, range: 5...300
staleDaysThreshold: Int     // default: 7, range: 1...90
notificationsEnabled: Bool  // default: true
showSizeInMenuBar: Bool     // default: true
launchAtLogin: Bool         // reads from SMAppService.mainApp.status
lastDeleteError: String?    // surfaced in footer when non-nil
notificationsDenied: Bool   // true when system notification permission is denied
checkForUpdatesAutomatically: Bool // default: true (in UpdateService)
lastUpdateCheckTime: Date?  // epoch stored in UserDefaults (in UpdateService)
dismissedUpdateVersion: String? // skip showing banner for this version (in UpdateService)
historyRetentionDays: Int       // default: 7, range: 1...30 (in HistoryService)
```
- Saved to `UserDefaults` via `@Published var` with `didSet` persistence pattern
- Default values loaded in `MonitorService.init()` using `defaults.object(forKey:) as? Type ?? fallback`
- Values are clamped to valid ranges both at load time and in `didSet` blocks
- UserDefaults keys are defined in `SettingsKey` enum (static string constants)
- Computed properties `warningBytes` / `criticalBytes` provide pre-converted threshold values

#### 5. File Deletion
- **Path validation allowlist**: symlink targets are only deleted if the resolved path starts with `/private/tmp/claude-` or `~/.claude/projects/`. Out-of-scope targets are skipped — the symlink itself is always removed to clean up the directory entry.
- Deleting a file: validates symlink target scope, removes target if allowed, then removes the symlink/file entry itself
- Deleting a project: validates each symlink target, removes allowed targets, then removes the entire project directory via `removeItem(atPath:)`
- Batch deletion: `deleteAllProjects()` deletes all projects and scans once at the end (not per-project)
- Broken symlink cleanup: `deleteBrokenSymlinks()` removes all dangling symlink entries globally; `deleteBrokenSymlinksInProject(_:)` scopes to one project. Only removes the symlink file itself (no target exists).
- UI uses inline confirm/cancel buttons (tracked by `DeleteConfirmation` enum in ContentView)
- Deletion errors are surfaced via `lastDeleteError` published property, shown in the footer
- No communication protocol — all operations are local filesystem

#### 6. Auto-Update (UpdateService)
- Periodically checks `https://api.github.com/repos/underactive/scumbag-claude/releases/latest` (default: once per day)
- Compares remote `tag_name` (stripped of leading "v") against `CFBundleShortVersionString` using semantic version comparison
- States: `.idle` → `.checking` → `.available(version, downloadURL, releaseNotes)` / `.upToDate` / `.error(msg)`
- Download flow: `.available` → `.downloading(progress)` → `.readyToInstall(appPath)` → `.installing`
- Downloads zip to temp directory, extracts with `/usr/bin/ditto -xk`, verifies `.app` bundle exists
- Self-replacement: writes a bash script that waits for current process to exit, replaces the `.app` bundle, clears quarantine (`xattr -cr`), and relaunches
- Pre-checks `Bundle.main.bundlePath` for `.app` suffix and write permissions; shows manual update message for dev builds
- Users can dismiss a version (persisted as `dismissedUpdateVersion`); dismissed versions don't show the banner
- UI: update banner in popover between projects and footer, "Check for Updates..." in right-click menu, update status in About dialog, auto-check toggle in Settings

### Data Flow
`MonitorService`, `UpdateService`, and `HistoryService` are created and owned by `AppDelegate`. All three are passed to `ContentView` (popover) and `SettingsView` (dialog) via `.environmentObject()`. `UpdateService` is also passed to `AboutView`. `HistoryService` is passed to `StatsView`. `MonitorService.onScanComplete` closure bridges scan results to `HistoryService.recordSnapshot()`. All state mutations happen on `@MainActor`. FSEvents callbacks dispatch to `@MainActor` via `Task`, debounce with 0.5s delay, then call `scan()`. Timer callbacks dispatch back to `@MainActor` via `Task`. Menubar icon/title updates are driven by a `Combine` subscriber on `monitor.$status`, `monitor.$totalSize`, and `monitor.$showSizeInMenuBar`. `HistoryService` saves to disk every 60s via its own timer, plus on `applicationWillTerminate`.

---

## Build Configuration

### Swift Package Manager Configuration
- **swift-tools-version: 5.9** — minimum toolchain version
- **platforms: [.macOS(.v13)]** — requires macOS Ventura or later
- **`.process("Resources")`** — SPM processes resources in `Sources/ClaudeTmpMonitor/Resources/`, making them available via `Bundle.module`

### Makefile Configuration
- **APP_NAME = "Scumbag Claude"** — display name differs from executable name (`ClaudeTmpMonitor`)
- **`make bundle`** — creates `.app` bundle manually: copies executable, `Info.plist`, `AppIcon.icns`, and SPM resource bundle into standard macOS bundle structure
- **`make run`** runs release build (not debug) — the `run` target depends on `build` which uses `-c release`

### Environment Variables

No environment variables are used. All configuration is runtime via `UserDefaults`.

---

## Code Style

- **Linter:** None configured
- **Formatter:** None configured
- **Indentation:** 4 spaces
- **Line endings:** LF
- Follows standard Swift conventions: `MARK` comments for section organization, structs for value types, classes for reference types with `@MainActor` isolation

---

## External Integrations

No external services or third-party SDKs. All operations are local filesystem and system notifications.

---

## Known Issues / Limitations

1. **No auto-cleanup** — Settings exist for thresholds but auto-deletion is not yet implemented.
2. **Hardcoded skip words in `extractProjectName`** — The display name extractor has a hardcoded `skipWords` set (`Users`, `Development`, `personal`, `hardware`, `esison`) that won't work for other users.
3. **No TOCTOU protection on delete** — Symlink targets are not re-resolved at delete time. A symlink could be retargeted between scan and delete. Deferred to separate plan.
4. **Gatekeeper quarantine on auto-update** — Downloaded update may trigger Gatekeeper re-validation. Mitigated by `xattr -cr` in the updater script, but users may see a brief security prompt.
5. **No delta updates** — Auto-update downloads the full zip archive every time. No binary diff/patch mechanism.
6. **No checksum verification on updates** — Downloaded zip is not verified against a SHA256 hash. Relies on HTTPS transport security.

---

## Development Rules

### 1. Validate all external input at the boundary
File system operations can fail at any time. Always use `try?` or proper error handling for `FileManager` operations. Never assume a path exists or is accessible.

### 2. Guard all array-indexed lookups
Use safe access patterns for collections returned by directory enumeration. Values from `FileManager` may be empty or unexpected.

### 3. Avoid memory-fragmenting patterns in long-running code
The app runs continuously as a menubar process. Prefer value types (structs) and avoid unbounded growth of collections (e.g., cap `notifiedPaths` set to prevent memory creep over days/weeks of runtime).

### 4. Use symbolic constants, not magic numbers
Threshold values come from settings. Conversion factors (e.g., `1024 * 1024` for MB) should be clear in context. Use `86400` for seconds-per-day with clear variable naming.

### 5. Throttle event-driven output
Notifications use per-path tracking to fire only once per threshold crossing. Any new notification-like features must implement similar deduplication.

### 6. Report errors, don't silently fail
When file operations fail, the current pattern is to use `try?` and skip the entry. If adding user-visible operations, provide feedback rather than silently failing.

---

## Plan Pre-Implementation

Before planning, check `docs/CLAUDE.md/plans/` for prior plans that touched the same areas. Scan the **Files changed** lists in both `implementation.md` and `audit.md` files to find relevant plans without reading every file — then read the full `plan.md` only for matches. This keeps context window usage low while preserving access to project history.

When a plan is finalized and about to be implemented, write the full plan to `docs/CLAUDE.md/plans/{epoch}-{plan_name}/plan.md`, where `{epoch}` is the Unix timestamp at the time of writing and `{plan_name}` is a short kebab-case description of the plan (e.g., `1709142000-add-user-auth/plan.md`).

The epoch prefix ensures chronological ordering — newer plans visibly supersede earlier ones at a glance based on directory name ordering.

The plan document should include:
- **Objective** — what is being implemented and why
- **Changes** — files to modify/create, with descriptions of each change
- **Dependencies** — any prerequisites or ordering constraints between changes
- **Risks / open questions** — anything flagged during planning that needs attention

---

## Plan Post-Implementation

After a plan has been fully implemented, write the completed implementation record to `docs/CLAUDE.md/plans/{epoch}-{plan_name}/implementation.md`, using the same directory as the corresponding `plan.md`.

The implementation document **must** include:
- **Files changed** — list of all files created, modified, or deleted. This section is **required** — it serves as a lightweight index for future planning, allowing prior plans to be found by scanning file lists without reading full plan contents.
- **Summary** — what was actually implemented (noting any deviations from the plan)
- **Verification** — steps taken to verify the implementation is correct (tests run, manual checks, build confirmation)
- **Follow-ups** — any remaining work, known limitations, or future improvements identified during implementation

If the implementation added or changed user-facing behavior (new settings, UI modes, protocol commands, or display changes), add corresponding `- [ ]` test items to `docs/CLAUDE.md/testing-checklist.md`. Each item should describe the expected observable behavior, not the implementation detail.

---

## Post-Implementation Audit

After finishing implementation of a plan, run the following subagents **in parallel** to audit all changed files.

> **Scope directive for all subagents:** Only flag issues in the changed code and its immediate dependents. Do not audit the entire codebase.

> **Output directive:** After all subagents complete, write a single consolidated audit report to `docs/CLAUDE.md/plans/{epoch}-{plan_name}/audit.md`, using the same directory as the corresponding `plan.md`. The audit report **must** include a **Files changed** section listing all files where findings were flagged. This section is **required** — it serves as a lightweight index for future planning, covering files affected by audit findings (including immediate dependents not in the original implementation).

### 1. QA Audit (subagent)
Review changes for:
- **Functional correctness**: broken workflows, missing error/loading states, unreachable code paths, logic that doesn't match spec
- **Edge cases**: empty/null/undefined inputs, zero-length collections, off-by-one errors, race conditions, boundary values (min/max/overflow)
- **Infinite loops**: unbounded `while`/recursive calls, callbacks triggering themselves, retry logic without max attempts or backoff
- **Performance**: unnecessary computation in hot paths, O(n²) or worse in loops over growing data, unthrottled event handlers, expensive operations blocking main thread or interrupt context

### 2. Security Audit (subagent)
Review changes for:
- **Injection / input trust**: unsanitized external input used in commands, queries, or output rendering; format string vulnerabilities; untrusted data used in control flow
- **Overflows**: unbounded buffer writes, unguarded index access, integer overflow/underflow in arithmetic, unchecked size parameters
- **Memory leaks**: allocated resources not freed on all exit paths, event/interrupt handlers not deregistered on cleanup, growing caches or buffers without eviction or bounds
- **Hard crashes**: null/undefined dereferences without guards, unhandled exceptions in async or interrupt context, uncaught error propagation across module boundaries

### 3. Interface Contract Audit (subagent)
Review changes for:
- **Data shape mismatches**: caller assumptions that diverge from actual API/protocol schema, missing fields treated as present, incorrect type coercion or endianness
- **Error handling**: no distinction between recoverable and fatal errors, swallowed failures, missing retry/backoff on transient faults, no timeout or watchdog configuration
- **Auth / privilege flows**: credential or token lifecycle issues, missing permission checks, race conditions during handshake or session refresh
- **Data consistency**: optimistic state updates without rollback on failure, stale cache served after mutation, sequence counters or cursors not invalidated after writes

### 4. State Management Audit (subagent)
Review changes for:
- **Mutation discipline**: shared state modified outside designated update paths, state transitions that skip validation, side effects hidden inside getters or read operations
- **Reactivity / observation pitfalls**: mutable updates that bypass change detection or notification mechanisms, deeply nested state triggering unnecessary cascading updates
- **Data flow**: excessive pass-through of context across layers where a shared store or service belongs, sibling modules communicating via parent state mutation, event/signal spaghetti without cleanup
- **Sync issues**: local copies shadowing canonical state, multiple sources of truth for the same entity, concurrent writers without arbitration (locks, atomics, or message ordering)

### 5. Resource & Concurrency Audit (subagent)
Review changes for:
- **Concurrency**: data races on shared memory, missing locks/mutexes/atomics around critical sections, deadlock potential from lock ordering, priority inversion in RTOS or threaded contexts
- **Resource lifecycle**: file handles, sockets, DMA channels, or peripherals not released on error paths; double-free or use-after-free; resource exhaustion under sustained load
- **Timing**: assumptions about execution order without synchronization, spin-waits without yield or timeout, interrupt latency not accounted for in real-time constraints
- **Power & hardware**: peripherals left in active state after use, missing clock gating or sleep transitions, watchdog not fed on long operations, register access without volatile or memory barriers

### 6. Testing Coverage Audit (subagent)
Review changes for:
- **Missing tests**: new public functions/modules without corresponding unit tests, modified branching logic without updated assertions, deleted tests not replaced
- **Test quality**: assertions on implementation details instead of behavior, tests coupled to internal structure, mocked so heavily the test proves nothing
- **Integration gaps**: cross-module flows tested only with mocks and never with integration or contract tests, initialization/shutdown sequences untested, error injection paths uncovered
- **Flakiness risks**: tests dependent on timing or sleep, shared mutable state between test cases, non-deterministic data (random IDs, timestamps), hardware-dependent tests without abstraction layer

### 7. DX & Maintainability Audit (subagent)
Review changes for:
- **Readability**: functions exceeding ~50 lines, boolean parameters without named constants, magic numbers/strings without explanation, nested ternaries or conditionals deeper than one level
- **Dead code**: unused includes/imports, unreachable branches behind stale feature flags, commented-out blocks with no context, exported symbols with zero consumers
- **Naming & structure**: inconsistent naming conventions, business/domain logic buried in UI or driver layers, utility functions duplicated across modules
- **Documentation**: public API changes without updated doc comments, non-obvious workarounds missing a `// WHY:` comment, breaking changes without migration notes

---

## Audit Post-Implementation

After audit findings have been addressed, update the `implementation.md` file in the corresponding `docs/CLAUDE.md/plans/{epoch}-{plan_name}/` directory:

1. **Flag fixed items** — In the audit report (`docs/CLAUDE.md/plans/{epoch}-{plan_name}/audit.md`), mark each finding that was fixed with a `[FIXED]` prefix so it is visually distinct from unresolved items.

2. **Append a fixes summary** — Add an `## Audit Fixes` section at the end of `implementation.md` containing:
   - **Fixes applied** — a numbered list of each fix, referencing the audit finding it addresses (e.g., "Fixed unchecked index access flagged by Security Audit §2")
   - **Verification checklist** — a `- [ ]` checkbox list of specific tests or manual checks to confirm each fix is correct (e.g., "Verify bounds check on `configIndex` with out-of-range input returns fallback")

3. **Leave unresolved items as-is** — Any audit findings intentionally deferred or accepted as-is should remain unmarked in the audit report. Add a brief note in the fixes summary explaining why they were not addressed.

4. **Update testing checklist** — If any audit fixes changed user-facing behavior, add corresponding `- [ ]` test items to `docs/CLAUDE.md/testing-checklist.md`. Each item should describe the expected observable behavior, not the implementation detail.

---

## Common Modifications

### Version bumps
Version string appears in 2 files:
1. `Info.plist` — `CFBundleVersion` and `CFBundleShortVersionString`
2. `CLAUDE.md` — Project Overview section

**Keep all version references in sync.** Always bump all files together during any version bump.

### Add a new setting
1. Add `@Published var` with `didSet` UserDefaults persistence in `MonitorService`
2. Load default in `MonitorService.init()` using `defaults.object(forKey:) as? Type ?? fallback`
3. Add UI row in `ContentView.settingsSection` using the `settingRow()` helper
4. Document the setting in CLAUDE.md Architecture > Settings section

### Add a new monitored path pattern
1. Modify `scan()` in `MonitorService.swift` to include the new pattern
2. Update the monitored directory structure in CLAUDE.md Architecture > File Monitoring

### Change the GitHub repository URL for updates
1. Update `githubAPIURL` in `UpdateService.swift`
2. Update `githubURL` in `AboutView.swift`
3. Update any references in CLAUDE.md

---

## File Inventory

| File / Directory | Purpose |
|------------------|---------|
| `Package.swift` | SPM package definition (macOS 13+, swift-tools-version 5.9) |
| `Sources/ClaudeTmpMonitor/App.swift` | `@main` entry, `AppDelegate` with `NSStatusItem`, popover, right-click menu, Settings/About/Statistics windows |
| `Sources/ClaudeTmpMonitor/MonitorService.swift` | Monitoring logic, models, settings, notifications, `onScanComplete` callback |
| `Sources/ClaudeTmpMonitor/HistoryService.swift` | Historical data: snapshot recording, two-tier aggregation, JSON persistence, retention, querying |
| `Sources/ClaudeTmpMonitor/UpdateService.swift` | Auto-update: GitHub releases API check, download, self-replacement |
| `Sources/ClaudeTmpMonitor/ContentView.swift` | Main popover view (header, status, projects, update banner, footer with Stats button) |
| `Sources/ClaudeTmpMonitor/StatsView.swift` | Statistics window: SwiftUI Charts area+line chart, time range picker, summary stats |
| `Sources/ClaudeTmpMonitor/SettingsView.swift` | Settings dialog view (includes history retention) |
| `Sources/ClaudeTmpMonitor/AboutView.swift` | About dialog view |
| `Sources/ClaudeTmpMonitor/Resources/` | `MenuBarIcon.png`, `MenuBarIcon@2x.png`, `AppIcon.icns` |
| `Info.plist` | App bundle config (`LSUIElement=true`, bundle ID `com.esison.claude-tmp-monitor`) |
| `Makefile` | Build, bundle, install, run, clean targets |
| `CLAUDE.md` | This file |
| `CLAUDE_TEMPLATE.md` | Template for generating CLAUDE.md files |
| `docs/` | Plans, testing checklist, version history, future improvements |
| `docs/CLAUDE.md/plans/` | Plan, implementation, and audit records (epoch-prefixed directories for chronological ordering) |
| `assets/` | Source artwork (`ScumbagCap.png`) used to generate menubar icon silhouette |

---

## Build Instructions

### Prerequisites
- Xcode 15+ or Swift 5.9+ toolchain
- macOS 13 (Ventura) or later

### Quick Start
```bash
swift build              # Debug build
make build               # Release build
make bundle              # Release build + .app bundle at .build/release/Scumbag Claude.app
make install             # Bundle + copy to /Applications
make run                 # Release build and run
make clean               # Clean build artifacts
```

Running without the `.app` bundle (`swift run` or `.build/debug/ClaudeTmpMonitor`) will show a Dock icon since `Info.plist` (`LSUIElement`) isn't loaded. The programmatic `setActivationPolicy(.accessory)` fallback handles this.

### Troubleshooting Build
- **"no such module 'SwiftUI'"** — Ensure Xcode command-line tools are installed: `xcode-select --install`
- **Dock icon appears when running** — Run via `make bundle && open ".build/release/Scumbag Claude.app"` to get proper menubar-only behavior

---

## Testing

No test target exists yet. See `docs/CLAUDE.md/testing-checklist.md` for the manual QA testing checklist.

---

## Future Improvements

See `docs/CLAUDE.md/future-improvements.md` for the ideas backlog.

---

## Maintaining This File

### Keep CLAUDE.md in sync with the codebase
**Every plan that adds, removes, or changes a feature must include CLAUDE.md updates as part of the implementation.** Treat CLAUDE.md as a living spec -- if the code and this file disagree, this file is wrong and must be fixed before the work is considered complete. During plan post-implementation, verify that all sections affected by the change are accurate. If a feature is removed, delete its documentation here rather than leaving stale references.

### When to update CLAUDE.md
- **Adding a new subsystem or module** — add it to Architecture and File Inventory
- **Adding a new setting or config field** — update the Settings section and Common Modifications
- **Discovering a new bug class** — add a Development Rule to prevent recurrence
- **Changing the build process** — update Build Instructions and/or Build Configuration
- **Adding/changing env vars or build defines** — update Build Configuration > Environment Variables
- **Changing linting or style rules** — update Code Style
- **Integrating a new third-party service or SDK** — add to External Integrations
- **Bumping the version** — update the version in Project Overview
- **Adding/removing files** — update File Inventory
- **Finding a new limitation** — add to Known Issues

### Supplementary docs
For sections that grow large (display layouts, testing checklists, changelogs), move them to separate files under `docs/` and link from here. This keeps the main CLAUDE.md scannable while preserving detail.

### Future improvements tracking
When a new feature is added and related enhancements or follow-up ideas are suggested but declined, add them as `- [ ]` items to `docs/CLAUDE.md/future-improvements.md`. This preserves good ideas for later without cluttering the current task.

### Version history maintenance
When making changes that are committed to the repository, add a row to the version history table in `docs/CLAUDE.md/version-history.md`. Each entry should include:

- **Ver** — A semantic version identifier (e.g., `v0.1.0`, `v0.2.0`). Follow semver: MAJOR.MINOR.PATCH. Use the most recent entry in the table to determine the next version number.
- **Changes** — A brief summary of what changed.

Append new rows to the bottom of the table. Do not remove or rewrite existing entries.

### Testing checklist maintenance
When adding or modifying user-facing behavior (new settings, UI modes, protocol commands, or display changes), add corresponding `- [ ]` test items to `docs/CLAUDE.md/testing-checklist.md`. Each item should describe the expected observable behavior, not the implementation detail.

### What belongs here vs. in code comments
- **Here:** Architecture decisions, cross-cutting concerns, "how things fit together," gotchas, recipes
- **In code:** Implementation details, function-level docs, inline explanations of tricky logic

---

## Origin

Created with Claude (Anthropic)
