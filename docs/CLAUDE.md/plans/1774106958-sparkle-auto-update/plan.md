# Plan: Migrate Auto-Update to Sparkle 2.x

## Objective

Replace the custom 445-line `UpdateService.swift` (GitHub API polling, DMG download/mount/extract, shell script self-replacement) with the Sparkle 2.x framework. This eliminates custom update code, resolves known issues #4 (Gatekeeper quarantine), #5 (no delta updates), and #6 (no checksum verification), and provides EdDSA signature verification plus a standard macOS update UI.

## Changes

- `Package.swift` — Add Sparkle 2.6+ SPM binary dependency
- `Info.plist` — Add `SUFeedURL` and `SUPublicEDKey` keys
- `Sources/ClaudeTmpMonitor/UpdateService.swift` — Delete entirely
- `Sources/ClaudeTmpMonitor/App.swift` — Replace `UpdateService` with `SPUStandardUpdaterController`, rewire "Check for Updates" menu item
- `Sources/ClaudeTmpMonitor/ContentView.swift` — Remove update banner section (~98 lines)
- `Sources/ClaudeTmpMonitor/AboutView.swift` — Remove update status display, simplify to static version
- `Sources/ClaudeTmpMonitor/SettingsView.swift` — Accept `SPUUpdater` as init parameter, rewire auto-check toggle
- `Sources/ClaudeTmpMonitor/MonitorService.swift` — Remove 3 orphaned `SettingsKey` constants
- `Makefile` — Embed Sparkle.framework in `Contents/Frameworks/`, set rpath, inside-out framework signing
- `.github/workflows/release.yml` — Add framework signing, Sparkle tools download, EdDSA DMG signing, appcast generation on gh-pages
- `CLAUDE.md` — Update all affected sections

## Dependencies

1. Package.swift must be updated first (Sparkle needed to import)
2. Makefile depends on knowing the framework artifact path (from first build)
3. All consumer changes (ContentView, AboutView, SettingsView) depend on App.swift changes
4. release.yml changes can be developed in parallel with code changes

## Risks / Open Questions

1. Sparkle.framework artifact path in `.build/` may vary between SPM versions
2. SPM executable target with manually-bundled Info.plist — Sparkle needs `Bundle.main` to have SUFeedURL
3. Inside-out framework signing — exact signable binaries may vary between Sparkle versions
4. GitHub Pages propagation delay (1-10 min) after appcast push
5. EdDSA keypair must be generated as a one-time prerequisite
