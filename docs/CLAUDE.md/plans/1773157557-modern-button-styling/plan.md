# Plan: Modern Button Styling for Footer Actions

## Objective
Replace plain-styled text buttons in the popover footer with macOS-native bordered buttons. The footer buttons (Settings, Clean All, Confirm/Cancel, Quit) currently use `.buttonStyle(.plain)` with manual foreground colors, which look like text links rather than proper buttons. Using `.bordered` style provides a native macOS appearance while staying compatible with the macOS 13+ deployment target.

## Changes

### `Sources/ClaudeTmpMonitor/ContentView.swift`
Modify the `footerSection` computed property:

1. **Settings button**: Replace `.buttonStyle(.plain)` + `.foregroundColor(.secondary)` with `.buttonStyle(.bordered)` + `.controlSize(.small)`.
2. **Clean All button**: Replace `.buttonStyle(.plain)` + `.foregroundColor(.orange)` with `.buttonStyle(.bordered)` + `.controlSize(.small)` + `.tint(.orange)`.
3. **Confirm/Cancel buttons**: Replace `.buttonStyle(.plain)` with `.buttonStyle(.bordered)` + `.controlSize(.small)`. Add `.tint(.red)` on Confirm.
4. **Quit button**: Replace `.buttonStyle(.plain)` + `.foregroundColor(.secondary)` with `.buttonStyle(.bordered)` + `.controlSize(.small)`.

## Dependencies
None. Single-file change with no cross-file dependencies.

## Risks / open questions
- `.tint(.orange)` on bordered buttons may render differently across macOS versions (13 vs 14+). Visual verification needed.
