# Plan: Growth Rate Tracking

## Objective

Track file sizes across successive scans to compute per-file growth rates, displaying "↑ X.X MB/min" indicators on project and file rows. This surfaces which files are actively growing — the primary signal for catching runaway Claude agent output.

## Changes

### `Sources/ClaudeTmpMonitor/MonitorService.swift`

**Model changes:**
- Add `growthRate: Double?` to `MonitoredFile` (bytes/sec, nil when not growing or no prior data)
- Add `growthRate: Double` computed property to `ClaudeProject` (sum of file growth rates)

**State tracking:**
- Add `private var previousSizes: [String: (size: UInt64, time: Date)] = [:]` keyed by resolved path
- Ephemeral runtime state — no UserDefaults persistence

**Scan logic (in `scan()`):**
- Capture `scanTime = Date()` at start for consistent timestamps
- After `scanDirectory` returns files, map over them to fill in `growthRate` by comparing to `previousSizes`
- Growth rate = `Double(sizeDelta) / timeDelta` when file existed before AND grew
- After scan completes, rebuild `previousSizes` from current files (implicitly prunes stale entries)

**Formatting:**
- Add `formatGrowthRate(_ bytesPerSecond: Double) -> String?` free function next to `formatBytes`
- Returns nil if rate <= 0
- Converts to per-minute, selects appropriate unit (KB/min, MB/min, GB/min)

### `Sources/ClaudeTmpMonitor/ContentView.swift`

**Project row:** After size text, before delete button:
```swift
if project.growthRate > 0, let rateText = formatGrowthRate(project.growthRate) {
    Text("↑ \(rateText)")
        .font(.caption.monospacedDigit())
        .foregroundColor(.orange)
}
```

**File row:** After size text, before delete button:
```swift
if let rate = file.growthRate, rate > 0, let rateText = formatGrowthRate(rate) {
    Text("↑ \(rateText)")
        .font(.caption2.monospacedDigit())
        .foregroundColor(.orange)
}
```

### `CLAUDE.md`
- Update MonitoredFile and ClaudeProject model docs
- Add previousSizes to private properties list

### `docs/CLAUDE.md/future-improvements.md`
- Mark growth rate tracking as done `[x]`

## Dependencies

Sequential: model fields → scan logic + formatter → UI → docs

## Risks / Open Questions

1. **First scan shows nil** — no prior data. Expected; UI hides indicators gracefully.
2. **Spike after restart** — first computed rate may be artificially high if file grew while app was closed. Acceptable for v1; self-corrects on next scan.
3. **Layout pressure** — growth rate text adds ~80px. Only appears for actively growing files. Project name already has `lineLimit(1)`.
4. **Division by zero** — guarded by `timeDelta > 0` check.
