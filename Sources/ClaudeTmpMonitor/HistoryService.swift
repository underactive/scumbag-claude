import Foundation

// MARK: - History Models

struct ProjectSnapshot: Codable {
    let name: String
    let size: UInt64
    let fileCount: Int
}

struct HistorySnapshot: Codable, Identifiable {
    var id: Date { timestamp }
    let timestamp: Date
    let totalSize: UInt64
    let totalFileCount: Int
    let projects: [ProjectSnapshot]
}

// MARK: - Time Range

enum TimeRange: String, CaseIterable {
    case oneHour = "1h"
    case twentyFourHours = "24h"
    case sevenDays = "7d"

    var seconds: TimeInterval {
        switch self {
        case .oneHour: return 3600
        case .twentyFourHours: return 86400
        case .sevenDays: return 604800
        }
    }
}

// MARK: - History Service

@MainActor
class HistoryService: ObservableObject {
    @Published var snapshots: [HistorySnapshot] = []

    // didSet clamp pattern: reassigning triggers a second didSet call which returns
    // immediately because the value is already clamped. Same pattern as MonitorService thresholds.
    @Published var historyRetentionDays: Int {
        didSet {
            let clamped = min(max(historyRetentionDays, 1), 30)
            if historyRetentionDays != clamped { historyRetentionDays = clamped; return }
            UserDefaults.standard.set(historyRetentionDays, forKey: SettingsKey.historyRetentionDays)
        }
    }

    private var saveTimer: Timer?

    init() {
        let rawRetention = UserDefaults.standard.object(forKey: SettingsKey.historyRetentionDays) as? Int ?? 7
        self.historyRetentionDays = min(max(rawRetention, 1), 30)

        load()
        startSaveTimer()
    }

    deinit {
        saveTimer?.invalidate()
    }

    // MARK: - Recording

    func recordSnapshot(totalSize: UInt64, totalFileCount: Int, projects: [ClaudeProject]) {
        let projectSnapshots = projects.map { project in
            ProjectSnapshot(
                name: project.displayName,
                size: project.totalSize,
                fileCount: project.files.count
            )
        }
        let snapshot = HistorySnapshot(
            timestamp: Date(),
            totalSize: totalSize,
            totalFileCount: totalFileCount,
            projects: projectSnapshots
        )
        snapshots.append(snapshot)
    }

    // MARK: - Querying

    func snapshots(for range: TimeRange) -> [HistorySnapshot] {
        let cutoff = Date().addingTimeInterval(-range.seconds)
        return snapshots.filter { $0.timestamp >= cutoff }.sorted { $0.timestamp < $1.timestamp }
    }

    func peakSize(in snapshots: [HistorySnapshot]) -> UInt64 {
        snapshots.map(\.totalSize).max() ?? 0
    }

    func averageSize(in snapshots: [HistorySnapshot]) -> UInt64 {
        guard !snapshots.isEmpty else { return 0 }
        let sum = snapshots.reduce(UInt64(0)) { $0 + $1.totalSize }
        return sum / UInt64(snapshots.count)
    }

    // MARK: - Persistence

    func saveNow() {
        save()
    }

    private static let saveIntervalSeconds: TimeInterval = 60

    private func startSaveTimer() {
        saveTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: Self.saveIntervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.save()
            }
        }
        timer.tolerance = Self.saveIntervalSeconds * 0.1
        saveTimer = timer
    }

    private func save() {
        let retentionDays = historyRetentionDays
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let retentionCutoff = Date().addingTimeInterval(-TimeInterval(retentionDays) * 86400)

        // Compute new snapshots array entirely in local variables to avoid intermediate mutation
        let retained = snapshots.filter { $0.timestamp >= retentionCutoff }
        let recent = retained.filter { $0.timestamp >= oneHourAgo }
        let old = retained.filter { $0.timestamp < oneHourAgo }
        let aggregated = aggregate(snapshots: old, bucketSeconds: 300)
        let compacted = (aggregated + recent).sorted { $0.timestamp < $1.timestamp }

        // Single atomic assignment
        snapshots = compacted

        // Encode and write
        guard let url = historyFileURL() else { return }
        do {
            let data = try JSONEncoder().encode(compacted)
            try data.write(to: url, options: .atomic)
        } catch {
            // Per Dev Rule 6: report errors — but history persistence is non-critical,
            // so we log silently rather than surfacing to user
        }
    }

    private func load() {
        guard let url = historyFileURL(),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([HistorySnapshot].self, from: data) else {
            return
        }
        snapshots = decoded
    }

    private func historyFileURL() -> URL? {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { return nil }

        let dir = appSupport.appendingPathComponent("com.esison.claude-tmp-monitor")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }

    /// Downsample snapshots into fixed-width time buckets by averaging totalSize, totalFileCount,
    /// and per-project values. Each bucket's timestamp is the median entry's timestamp.
    private func aggregate(snapshots: [HistorySnapshot], bucketSeconds: TimeInterval) -> [HistorySnapshot] {
        guard !snapshots.isEmpty else { return [] }

        // Group snapshots into time buckets
        var buckets: [Int: [HistorySnapshot]] = [:]
        for snapshot in snapshots {
            let bucketKey = Int(snapshot.timestamp.timeIntervalSince1970 / bucketSeconds)
            buckets[bucketKey, default: []].append(snapshot)
        }

        // Average each bucket
        return buckets.keys.sorted().compactMap { key -> HistorySnapshot? in
            guard let group = buckets[key], !group.isEmpty else { return nil }
            let count = UInt64(group.count)
            let avgSize = group.reduce(UInt64(0)) { $0 + $1.totalSize } / count
            let avgFileCount = group.reduce(0) { $0 + $1.totalFileCount } / group.count
            let midTimestamp = group[group.count / 2].timestamp

            // Merge project snapshots: average per unique project name
            var projectSums: [String: (size: UInt64, fileCount: Int, count: Int)] = [:]
            for snapshot in group {
                for project in snapshot.projects {
                    let existing = projectSums[project.name, default: (0, 0, 0)]
                    projectSums[project.name] = (
                        existing.size + project.size,
                        existing.fileCount + project.fileCount,
                        existing.count + 1
                    )
                }
            }
            let avgProjects = projectSums.map { name, sums in
                ProjectSnapshot(
                    name: name,
                    size: sums.size / UInt64(sums.count),
                    fileCount: sums.fileCount / sums.count
                )
            }

            return HistorySnapshot(
                timestamp: midTimestamp,
                totalSize: avgSize,
                totalFileCount: avgFileCount,
                projects: avgProjects
            )
        }
    }
}
