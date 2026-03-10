# Implementation: Dynamic Menubar Icon Color

## Files changed
- `Sources/ClaudeTmpMonitor/App.swift` — replaced single `cachedMenuBarImage` with status-based icon system
- `docs/CLAUDE.md/testing-checklist.md` — added Menubar Icon Color test section

## Summary
Implemented dynamic menubar icon coloring based on `MonitorStatus`:
- **Normal**: system-tinted template icon (adapts to light/dark mode)
- **Warning**: orange-tinted icon (`isTemplate = false`)
- **Critical**: red-tinted icon (`isTemplate = false`)

The base PNG is loaded once into a shared `baseImage` static. Three derived images are pre-cached at first access. The `image(for:)` helper maps `MonitorStatus` to the correct cached image. The `MenuBarExtra` label selects the image reactively via `monitor.status`.

Tinting uses `NSImage(size:flipped:drawingHandler:)` with `.sourceAtop` compositing to color only the opaque pixels of the icon.

## Verification
- `make build` — compiles successfully with no warnings
- `make bundle` — creates `.app` bundle

## Follow-ups
- None required. The `lockFocus` deprecation was addressed during audit remediation.

## Audit Fixes

### Fixes applied
1. Replaced deprecated `lockFocus()`/`unlockFocus()` with `NSImage(size:flipped:drawingHandler:)` (Resource & Concurrency Audit, DX Audit)
2. Extracted `iconSize` constant to eliminate magic number `18` (DX Audit §1)
3. Extracted shared `baseImage` static to load PNG once instead of 3 times (QA Audit §4a, DX Audit §2)
4. Added comment explaining `.sourceAtop` compositing technique (DX Audit §4)
5. Added 6 manual test items to `docs/CLAUDE.md/testing-checklist.md` (Testing Coverage Audit §3)

### Verification checklist
- [ ] Build succeeds with no warnings (`make build`)
- [ ] Icon appears system-tinted in normal status
- [ ] Icon turns orange at warning threshold
- [ ] Icon turns red at critical threshold
- [ ] Icon reverts to normal after cleanup
- [ ] Fallback SF Symbol renders when MenuBarIcon.png is missing

### Unresolved items
- **No unit tests**: Project has no test target; consistent with existing codebase. Not addressed.
- **Fallback SF Symbol not color-tinted**: Accepted as intentional graceful degradation.
- **No diagnostic log on resource load failure**: Deferred — silent fallback is acceptable.
