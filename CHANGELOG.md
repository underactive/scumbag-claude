# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-03-09

### Added

- macOS menubar app using SwiftUI `MenuBarExtra` with `.window` style
- Timer-based polling of `/private/tmp/claude-*/` directories (configurable interval, default 30s)
- Symlink resolution for accurate file size reporting with deduplication by resolved path
- Per-project file grouping with expandable details in the menubar dropdown
- Three-tier status system (Normal/Warning/Critical) with color-coded menubar icon
- System notifications on threshold crossings (once per file per threshold)
- Inline delete with confirmation for individual files, projects, and bulk cleanup
- Stale directory detection based on configurable age threshold (default 7 days)
- Configurable settings: warning/critical thresholds, scan interval, stale days, notifications toggle
- Launch-at-login support via macOS `ServiceManagement` (`SMAppService`)
- Menubar-only mode (no Dock icon) via `LSUIElement` in Info.plist with programmatic fallback
- App icon and menubar status icons (normal/warning/critical variants)
- Makefile with build, bundle, install, run, and clean targets
- README with build instructions and feature overview
