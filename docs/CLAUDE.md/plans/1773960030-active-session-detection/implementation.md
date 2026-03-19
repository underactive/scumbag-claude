# Implementation: Active Session Detection

## Files Changed

- `Sources/ClaudeTmpMonitor/MonitorService.swift` — Added `isActive` field to `ClaudeProject`, `activeSessionThreshold` constant (60s), computation in `scan()`, pass-through in dedup rebuild
- `Sources/ClaudeTmpMonitor/ContentView.swift` — Added `PulsingDot` view (self-contained animated circle), green "live" pill badge in `projectRow()` after stale badge
- `CLAUDE.md` — Updated MonitorService description, ContentView description, added "Active session detection" paragraph to File Monitoring subsection
- `docs/CLAUDE.md/testing-checklist.md` — Added 8 test items under "Active Session Detection" section
- `docs/CLAUDE.md/future-improvements.md` — Marked active session detection as `[x]` done

## Summary

Implemented exactly as planned. No deviations.

### MonitorService changes:
- Added `private static let activeSessionThreshold: TimeInterval = 60` next to `trendChangeThreshold`
- Added `let isActive: Bool` to `ClaudeProject` struct after `isStale`
- Computed `isActive` in `scan()` using OR of recency check and growth rate check
- Passed `isActive` through both the primary `ClaudeProject` initializer and the dedup rebuild

### ContentView changes:
- Added `PulsingDot` private struct with `@State isPulsing` and `.onAppear` trigger
- Added conditional "live" badge in `projectRow()` HStack after the "stale" badge, with green background, tooltip, and pulsing dot

## Verification

1. `swift build -c release` — clean build, no warnings
2. Active/stale are mutually exclusive by definition (60s vs days threshold)
3. `PulsingDot` lifecycle is correct: `if project.isActive` creates/destroys the view, giving each appearance a fresh `@State`

## Follow-ups

- Consider adding a deletion warning/confirmation for active projects (not blocking, per plan decision)
- The 60s threshold is hardcoded; if users request configurability, add to Settings

## Audit Fixes

### Fixes applied

1. **Replaced force-unwrap with nil-coalescing** — `($0.growthRate ?? 0) > 0` instead of `$0.growthRate != nil && $0.growthRate! > 0` (QA-1, IC-4, DX-1)
2. **Added mutual exclusion in UI** — `isStale && !project.isActive` ensures "live" takes priority over "stale" (QA-5, QA-8, IC-3, SM-5)
3. **Added `.onDisappear { isPulsing = false }`** — clean animation teardown on `PulsingDot` removal (RC-1)
4. **Added inline comment on `activeSessionThreshold`** — documents unit and purpose (QA-4, DX-3)
5. **Added doc comment on `ClaudeProject.isActive`** — explains two-part condition (DX-4)
6. **Added sync comment on dedup rebuild block** — "keep in sync with ClaudeProject init above" (DX-2)
7. **Added 5 additional testing checklist items** — covers stale+live edge case, growth-rate-driven isActive, dedup path, popover-open timing, growth-stops transition (TC-1 through TC-6)

### Verification checklist

- [x] Force-unwrap replaced: `($0.growthRate ?? 0) > 0` compiles and is semantically equivalent
- [x] Mutual exclusion: `isStale && !project.isActive` prevents contradictory badges
- [x] `PulsingDot` has `.onDisappear` counterpart to `.onAppear`
- [x] `swift build -c release` passes cleanly after all fixes
- [x] Testing checklist now has 13 items total for active session detection

### Unresolved items

- **DX-5** (hardcoded color on PulsingDot): Accepted — single call site; parameterizing is premature abstraction
- **DX-7** (stale badge has no tooltip): Pre-existing pattern; not in scope for this change
- **QA-2/IC-6** (isActive uses target mtime not symlink ctime): By design — file content recency is the intended signal
- **SM-3** (ordering dependency in scan): Correct ordering; mitigated by sync comment on dedup block
- **RC-2** (mtime lag for open file descriptors): Mitigated by growth-rate fallback; no code change needed
