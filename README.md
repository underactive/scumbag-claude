<p align="center">
  <img src="assets/ScumbagClaude.png" width="200" alt="Scumbag Claude">
</p>

<h1 align="center">Scumbag Claude</h1>

<p align="center">
  A macOS menubar app that monitors Claude Code's temporary files<br>
  before they eat your disk alive.
</p>

---

Claude Code writes task output to `/private/tmp/claude-*/` directories. These `.output` files (often symlinks to `.jsonl` files) can grow to hundreds of megabytes during long sessions and never clean themselves up. Scumbag Claude sits in your menubar, watches these directories, and lets you know when things get out of hand.

## Features

- **Menubar status indicator** -- icon changes color (green/orange/red) based on disk usage severity, with optional total size display
- **FSEvents monitoring** -- near-instant detection (~2.5s) of file changes via macOS filesystem events, with timer-based polling as a safety net
- **Per-project breakdown** -- groups files by Claude Code project, with expandable details showing individual file sizes
- **Growth rate tracking** -- shows per-file and per-project growth rates (e.g. "↑ 2.3 MB/min") for actively growing files
- **Symlink awareness** -- resolves symlinks to get actual sizes; "link only" badge for out-of-scope targets, "×N" badge for deduplicated files, broken symlink detection
- **System notifications** -- alerts when files cross warning or critical size thresholds (fires once per file per threshold, not repeatedly)
- **One-click cleanup** -- delete individual files, entire projects, clean all, or clean broken symlinks with inline confirmation
- **Stale directory detection** -- flags project directories that haven't been modified in a configurable number of days
- **Configurable thresholds** -- set your own warning/critical size limits, scan interval, and stale directory age
- **Settings & About dialogs** -- dedicated settings window and right-click context menu with About dialog
- **Launch at login** -- optional auto-start via macOS `ServiceManagement`
- **Menubar-only** -- no Dock icon, no windows cluttering your workspace

## Screenshots

<p align="center">
  <img src="assets/menu_screenshot.png" width="400" alt="Scumbag Claude menubar popover showing per-project file breakdown">
  &nbsp;&nbsp;
  <img src="assets/settings_sceenshot.png" width="300" alt="Scumbag Claude settings window">
</p>

## Why

Claude Code's Task tool writes `.output` files to `/private/tmp/claude-*/` that **never get cleaned up**. A single research-heavy session can generate hundreds of gigabytes, filling your disk without warning. This has been [reported as a bug](https://github.com/anthropics/claude-code/issues/26911) — one user hit **537 GB from a single session**, with disk-full emergencies 6+ times in 30 days. Until there's an official fix, Scumbag Claude watches these directories so you don't have to.

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15+ or Swift 5.9+ toolchain

## Build & Install

### Quick start

```bash
git clone https://github.com/underactive/scumbag-claude.git
cd scumbag-claude
make install
```

This builds a release binary, packages it into `Scumbag Claude.app`, and copies it to `/Applications`.

### All build targets

| Command | What it does |
|---------|-------------|
| `swift build` | Debug build |
| `make build` | Release build |
| `make bundle` | Release build + `.app` bundle at `.build/release/Scumbag Claude.app` |
| `make install` | Bundle + copy to `/Applications` |
| `make run` | Release build and run directly |
| `make clean` | Remove build artifacts |

### Running without the app bundle

You can run the executable directly with `swift run` or `make run`, but the Dock icon will appear since `Info.plist` (which sets `LSUIElement`) isn't loaded outside the `.app` bundle. A programmatic fallback handles this, but the bundle is the intended way to run it.

## Configuration

All settings are accessible from the menubar dropdown. Defaults:

| Setting | Default | Description |
|---------|---------|-------------|
| Warning threshold | 100 MB | File/total size that triggers orange status |
| Critical threshold | 500 MB | File/total size that triggers red status |
| Scan interval | 15 seconds | How often the fallback timer polls (FSEvents handles most detection) |
| Stale threshold | 7 days | Days before a project directory is considered stale |
| Notifications | Enabled | System notification alerts on threshold crossings |
| Show size in menu bar | Enabled | Display total disk usage next to the menubar icon |
| Launch at login | Disabled | Start automatically when you log in |

## How it works

Scumbag Claude uses macOS FSEvents to watch `/private/tmp` and `~/.claude/projects/` for filesystem changes, triggering a scan within ~2.5s of any change. A fallback timer polls every 15 seconds as a safety net. Each scan enumerates all subdirectories and files under `/private/tmp/claude-{uid}/`, resolves symlinks to get actual file sizes, deduplicates by resolved path, and groups everything by project. Growth rates are computed by comparing file sizes across successive scans. When a file crosses a size threshold, a system notification fires (once per file per threshold). The menubar icon updates to reflect the worst current status across all monitored files.

## License

MIT
