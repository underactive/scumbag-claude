# Implementation: Modern Button Styling for Footer Actions

## Files changed
- `Sources/ClaudeTmpMonitor/ContentView.swift` — modified `footerSection` computed property (4 button style changes)

## Summary
Replaced all `.buttonStyle(.plain)` usages in the footer with `.buttonStyle(.bordered)` + `.controlSize(.small)`. Removed manual `.foregroundColor()` calls that were simulating button appearance on plain text, replacing them with `.tint()` where color distinction is needed (orange for Clean All, red for Confirm). No deviations from the plan.

## Verification
- `swift build` succeeded with no errors or warnings
- Visual verification pending (user should run `make bundle && open ".build/release/Scumbag Claude.app"`)

## Follow-ups
- Visual verification of `.tint(.orange)` rendering on macOS 13 vs newer versions
- Verify 5-button layout doesn't overflow when Clean All confirmation is showing
- Verify `.font(.caption)` on Cancel/Confirm renders smaller than other buttons with `.controlSize(.small)`

## Audit Fixes

### Fixes applied
1. Fixed repeated `.buttonStyle(.bordered)` + `.controlSize(.small)` on all 5 buttons (DX Audit Finding 7.1) — hoisted both modifiers to the parent `HStack`, eliminating 10 lines of repetition.

### Verification checklist
- [x] `swift build` succeeds after hoisting modifiers to parent HStack
- [ ] Visually verify all footer buttons still render as bordered small buttons after modifier hoisting

### Unresolved items
- **Finding 1.1 (Layout crowding):** Pre-existing issue — 5 buttons in HStack when confirmation is active. Requires visual verification.
- **Finding 1.2 (Lost secondary de-emphasis):** Design decision — bordered buttons use system accent by default. User should verify if this is acceptable.
- **Finding 3.1 (macOS 13 .tint() compatibility):** Already tracked as follow-up.
- **Findings 7.2, 7.3 (Cosmetic consistency):** Low severity, deferred.
