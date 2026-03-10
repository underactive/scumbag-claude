# Audit: Modern Button Styling for Footer Actions

## Files changed
- `Sources/ClaudeTmpMonitor/ContentView.swift` — `footerSection` computed property

## Consolidated Findings

### 1. QA Audit

**Finding 1.1 (Medium — Layout):** When `confirmDelete == .all`, up to 5 bordered buttons appear simultaneously in the footer HStack (Settings, Clean All, Cancel, Confirm, Quit). Bordered buttons are wider than plain-text buttons, risking horizontal overflow in the 380px popover. Pre-existing issue exacerbated by the style change.

**Finding 1.2 (Low — Design):** Settings and Quit buttons lost their `.foregroundColor(.secondary)` visual de-emphasis. With `.bordered` style and no `.tint()`, they now have equal visual prominence to action buttons. The original color hierarchy (orange=warning, red=destructive, secondary=utility) is partially flattened.

**Finding 1.3 (Low — Edge Case):** `.font(.caption)` on Cancel/Confirm buttons may be overridden by `.controlSize(.small)` on bordered buttons. Visual verification needed.

### 2. Security Audit
No issues found. Changes are purely declarative view modifiers with no data flow, input handling, or resource allocation changes.

### 3. Interface Contract Audit

**Finding 3.1 (Low — Compatibility):** `.tint()` on `BorderedButtonStyle` may not render reliably on macOS 13 (minimum deployment target). The tinting behavior became consistent starting in macOS 14. On macOS 13, "Clean All" and "Confirm" buttons may show default accent color instead of orange/red. Already tracked as a follow-up in implementation.md.

### 4. State Management Audit
No issues found. All state access patterns and threading guarantees are unchanged.

### 5. Resource & Concurrency Audit
No issues found. Changes are purely presentational with no concurrency, resource lifecycle, or timing implications.

### 6. Testing Coverage Audit

**Finding 6.1 (Low — Gap):** No checklist item verifying visual consistency between bordered footer buttons and plain inline confirm/cancel buttons. The style difference is intentional per plan scope, but undocumented.

### 7. DX & Maintainability Audit

**[FIXED] Finding 7.1 (Medium — Repetition):** `.buttonStyle(.bordered)` + `.controlSize(.small)` was repeated on all 5 buttons. Fixed by hoisting both modifiers to the parent `HStack`, eliminating 10 lines of repetition. SwiftUI propagates both modifiers through the environment to child views.

**Finding 7.2 (Low — Consistency):** `.font()` placement is inconsistent — some buttons apply it to the inner `Text`, others to the `Button` itself, and the Quit button places it after `.buttonStyle` while others place it before. Not a bug (SwiftUI handles both), but reduces readability.

**Finding 7.3 (Low — Documentation):** Footer confirm/cancel uses `.bordered` + `.tint()` while inline project/file confirm/cancel uses `.plain` + `.foregroundColor()`. Intentional per plan scope but not documented with a comment.

## Summary

| # | Finding | Severity | Status |
|---|---------|----------|--------|
| 1.1 | 5 bordered buttons may crowd 380px HStack | Medium | Unresolved — pre-existing, verify visually |
| 1.2 | Settings/Quit lost secondary visual de-emphasis | Low | Unresolved — design decision |
| 1.3 | `.font(.caption)` may be overridden by `.controlSize(.small)` | Low | Unresolved — verify visually |
| 3.1 | `.tint()` unreliable on macOS 13 bordered buttons | Low | Tracked in implementation follow-ups |
| 6.1 | No checklist item for footer vs inline style contrast | Low | Unresolved |
| 7.1 | Repeated modifiers on 5 buttons | Medium | **[FIXED]** — hoisted to parent HStack |
| 7.2 | Inconsistent `.font()` placement | Low | Unresolved — cosmetic |
| 7.3 | Footer vs inline style difference undocumented | Low | Unresolved — cosmetic |
