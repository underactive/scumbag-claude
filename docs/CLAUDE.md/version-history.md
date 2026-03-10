# Version History

| Ver | Changes |
|-----|---------|
| v0.1.0 | Initial release: menubar monitor for Claude Code tmp files with per-project breakdown, status notifications, configurable thresholds, and one-click cleanup |
| v0.2.0 | Audit remediation: path validation on symlink deletion, settings clamping, typed delete confirmation, batch delete, accessibility labels & keyboard shortcuts, notification permission detection, timer tolerance, pluralization fixes, deprecated API cleanup. Dynamic menubar icon color: icon turns orange at warning threshold and red at critical threshold, with system-tinted template icon for normal status. Settings dialog + right-click About menu: replace MenuBarExtra with custom NSStatusItem, move settings into a separate window, add right-click context menu with About dialog (app icon, version, GitHub link), SF Symbol fallback icon when resource image is missing, reset stale confirmation state on popover reopen, remove dead code |
| v0.2.1 | UI polish: bordered macOS-native buttons in footer, hover effects on all buttons (red tint on delete actions), scumbag cap silhouette as menubar icon, popover opens focused, xmark icon cleanup. New setting: "Show size in menu bar" toggle to show/hide total disk usage next to menubar icon |
