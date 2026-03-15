import CoreServices
import Foundation
import ServiceManagement
import UserNotifications

// MARK: - Settings Keys

enum SettingsKey {
    static let warningThresholdMB = "warningThresholdMB"
    static let criticalThresholdMB = "criticalThresholdMB"
    static let scanIntervalSeconds = "scanIntervalSeconds"
    static let staleDaysThreshold = "staleDaysThreshold"
    static let notificationsEnabled = "notificationsEnabled"
    static let showSizeInMenuBar = "showSizeInMenuBar"
    static let checkForUpdatesAutomatically = "checkForUpdatesAutomatically"
    static let lastUpdateCheckTime = "lastUpdateCheckTime"
    static let dismissedUpdateVersion = "dismissedUpdateVersion"
    static let historyRetentionDays = "historyRetentionDays"
}

// MARK: - Models

struct MonitoredFile: Identifiable {
    var id: String { path }
    let path: String
    let resolvedPath: String
    let isSymlink: Bool
    let isBrokenSymlink: Bool
    let isTargetInScope: Bool // symlink target is safe to fully delete (within allowed paths)
    let size: UInt64
    let lastModified: Date
    let name: String
    let growthRate: Double? // bytes per second, nil when not growing or no prior data
    let duplicateCount: Int // how many files share the same resolvedPath (1 = unique)
}

struct ClaudeProject: Identifiable {
    var id: String { path }
    let path: String
    let name: String
    let displayName: String
    let totalSize: UInt64
    let files: [MonitoredFile]
    let lastModified: Date
    let isStale: Bool
    let claudeDir: String

    var growthRate: Double {
        files.compactMap(\.growthRate).reduce(0, +)
    }

    var brokenSymlinkCount: Int {
        files.filter(\.isBrokenSymlink).count
    }
}

enum MonitorStatus: String {
    case normal = "Normal"
    case warning = "Warning"
    case critical = "Critical"
}

// MARK: - Monitor Service

@MainActor
class MonitorService: ObservableObject {
    @Published var projects: [ClaudeProject] = []
    @Published var totalSize: UInt64 = 0
    @Published var totalFileCount: Int = 0
    @Published var status: MonitorStatus = .normal
    @Published var lastScanTime: Date?
    @Published var nextScanTime: Date?
    @Published var isScanning = false
    @Published var lastDeleteError: String?
    @Published var notificationsDenied: Bool = false

    // Settings
    @Published var warningThresholdMB: Int {
        didSet {
            let clamped = min(max(warningThresholdMB, 10), 1000000)
            if warningThresholdMB != clamped { warningThresholdMB = clamped; return }
            UserDefaults.standard.set(warningThresholdMB, forKey: SettingsKey.warningThresholdMB)
        }
    }
    @Published var criticalThresholdMB: Int {
        didSet {
            let clamped = min(max(criticalThresholdMB, 50), 1000000)
            if criticalThresholdMB != clamped { criticalThresholdMB = clamped; return }
            UserDefaults.standard.set(criticalThresholdMB, forKey: SettingsKey.criticalThresholdMB)
        }
    }
    @Published var scanIntervalSeconds: Int {
        didSet {
            let clamped = min(max(scanIntervalSeconds, 5), 300)
            if scanIntervalSeconds != clamped { scanIntervalSeconds = clamped; return }
            guard scanIntervalSeconds != oldValue else { return }
            UserDefaults.standard.set(scanIntervalSeconds, forKey: SettingsKey.scanIntervalSeconds)
            restartTimer()
        }
    }
    @Published var staleDaysThreshold: Int {
        didSet {
            let clamped = min(max(staleDaysThreshold, 1), 90)
            if staleDaysThreshold != clamped { staleDaysThreshold = clamped; return }
            UserDefaults.standard.set(staleDaysThreshold, forKey: SettingsKey.staleDaysThreshold)
        }
    }
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: SettingsKey.notificationsEnabled) }
    }
    @Published var showSizeInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showSizeInMenuBar, forKey: SettingsKey.showSizeInMenuBar) }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            guard !isUpdatingLaunchAtLogin else { return }
            isUpdatingLaunchAtLogin = true
            defer { isUpdatingLaunchAtLogin = false }
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    var warningBytes: UInt64 { UInt64(clamping: warningThresholdMB) * 1024 * 1024 }
    var criticalBytes: UInt64 { UInt64(clamping: criticalThresholdMB) * 1024 * 1024 }

    /// Called synchronously on @MainActor at the end of each scan() with the updated totals and projects.
    /// Callers must not trigger another scan() from within this closure (isScanning guard would silently no-op).
    var onScanComplete: ((UInt64, Int, [ClaudeProject]) -> Void)?

    private var timer: Timer?
    private var eventStream: FSEventStreamRef?
    private var debouncedScanTask: Task<Void, Never>?
    private var previousSizes: [String: (size: UInt64, time: Date)] = [:]
    private var notifiedPaths: Set<String> = []
    private var isUpdatingLaunchAtLogin = false

    init() {
        let defaults = UserDefaults.standard

        let rawWarning = defaults.object(forKey: SettingsKey.warningThresholdMB) as? Int ?? 100
        self.warningThresholdMB = min(max(rawWarning, 10), 1000000)

        let rawCritical = defaults.object(forKey: SettingsKey.criticalThresholdMB) as? Int ?? 500
        self.criticalThresholdMB = min(max(rawCritical, 50), 1000000)

        let rawInterval = defaults.object(forKey: SettingsKey.scanIntervalSeconds) as? Int ?? 15
        self.scanIntervalSeconds = min(max(rawInterval, 5), 300)

        let rawStale = defaults.object(forKey: SettingsKey.staleDaysThreshold) as? Int ?? 7
        self.staleDaysThreshold = min(max(rawStale, 1), 90)

        self.notificationsEnabled = defaults.object(forKey: SettingsKey.notificationsEnabled) as? Bool ?? true
        self.showSizeInMenuBar = defaults.object(forKey: SettingsKey.showSizeInMenuBar) as? Bool ?? true
        self.launchAtLogin = SMAppService.mainApp.status == .enabled

        requestNotificationPermission()
        checkNotificationAuthorization()
        startTimer()
        startFSEvents()

        Task { @MainActor in
            self.scan()
        }
    }

    deinit {
        // Inlined (can't call @MainActor stopFSEvents() from nonisolated deinit)
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
        }
        debouncedScanTask?.cancel()
        timer?.invalidate()
    }

    func scanNow() {
        scan()
    }

    func deleteFile(_ file: MonitoredFile) {
        lastDeleteError = nil
        let fm = FileManager.default
        var errors: [String] = []
        // If symlink, delete the target first to reclaim space (only if in allowed scope)
        if file.isSymlink && !file.isBrokenSymlink {
            if isInAllowedDeletionScope(file.resolvedPath) {
                do {
                    try fm.removeItem(atPath: file.resolvedPath)
                } catch {
                    errors.append("target: \(error.localizedDescription)")
                }
            }
        }
        // Delete the entry (symlink or actual file) — always in /private/tmp/claude-
        do {
            try fm.removeItem(atPath: file.path)
        } catch {
            errors.append(error.localizedDescription)
        }
        if !errors.isEmpty {
            lastDeleteError = "Failed to delete \(file.name): \(errors.joined(separator: "; "))"
        }
        notifiedPaths.remove(file.path)
        scan()
    }

    func deleteProject(_ project: ClaudeProject) {
        lastDeleteError = nil
        let fm = FileManager.default
        var targetErrors = 0
        // Delete symlink targets first to reclaim space from resolved locations (only if in allowed scope)
        for file in project.files where file.isSymlink && !file.isBrokenSymlink {
            if isInAllowedDeletionScope(file.resolvedPath) {
                do {
                    try fm.removeItem(atPath: file.resolvedPath)
                } catch {
                    targetErrors += 1
                }
            }
        }
        // Delete the entire project directory
        do {
            try fm.removeItem(atPath: project.path)
        } catch {
            lastDeleteError = "Failed to delete \(project.displayName): \(error.localizedDescription)"
        }
        if targetErrors > 0 && lastDeleteError == nil {
            lastDeleteError = "Failed to delete \(targetErrors) symlink target\(targetErrors == 1 ? "" : "s") in \(project.displayName)"
        }
        for file in project.files {
            notifiedPaths.remove(file.path)
        }
        scan()
    }

    func deleteAllProjects() {
        lastDeleteError = nil
        let fm = FileManager.default
        var errors: [String] = []
        for project in projects {
            var targetErrors = 0
            for file in project.files where file.isSymlink && !file.isBrokenSymlink {
                if isInAllowedDeletionScope(file.resolvedPath) {
                    do {
                        try fm.removeItem(atPath: file.resolvedPath)
                    } catch {
                        targetErrors += 1
                    }
                }
            }
            do {
                try fm.removeItem(atPath: project.path)
            } catch {
                errors.append(project.displayName)
            }
            if targetErrors > 0 {
                errors.append("\(targetErrors) target\(targetErrors == 1 ? "" : "s") in \(project.displayName)")
            }
            for file in project.files {
                notifiedPaths.remove(file.path)
            }
        }
        if !errors.isEmpty {
            lastDeleteError = "Failed to delete: \(errors.joined(separator: ", "))"
        }
        scan()
    }

    func deleteBrokenSymlinks() {
        lastDeleteError = nil
        let fm = FileManager.default
        var errorCount = 0
        for project in projects {
            for file in project.files where file.isBrokenSymlink {
                // Re-verify the entry is still a broken symlink before deleting (TOCTOU guard)
                let attrs = try? fm.attributesOfItem(atPath: file.path)
                let isStillSymlink = (attrs?[.type] as? FileAttributeType) == .typeSymbolicLink
                let targetExists = fm.fileExists(atPath: file.resolvedPath)
                guard isStillSymlink && !targetExists else { continue }

                do {
                    try fm.removeItem(atPath: file.path)
                    notifiedPaths.remove(file.path)
                } catch {
                    errorCount += 1
                }
            }
        }
        if errorCount > 0 {
            lastDeleteError = "Failed to remove \(errorCount) broken symlink\(errorCount == 1 ? "" : "s")"
        }
        scan()
    }

    func deleteBrokenSymlinksInProject(_ project: ClaudeProject) {
        lastDeleteError = nil
        let fm = FileManager.default
        var errorCount = 0
        for file in project.files where file.isBrokenSymlink {
            // Re-verify the entry is still a broken symlink before deleting (TOCTOU guard)
            let attrs = try? fm.attributesOfItem(atPath: file.path)
            let isStillSymlink = (attrs?[.type] as? FileAttributeType) == .typeSymbolicLink
            let targetExists = fm.fileExists(atPath: file.resolvedPath)
            guard isStillSymlink && !targetExists else { continue }

            do {
                try fm.removeItem(atPath: file.path)
                notifiedPaths.remove(file.path)
            } catch {
                errorCount += 1
            }
        }
        if errorCount > 0 {
            lastDeleteError = "Failed to remove \(errorCount) broken symlink\(errorCount == 1 ? "" : "s") in \(project.displayName)"
        }
        scan()
    }

    // MARK: - Path Validation

    private func isClaudeTmpPath(_ path: String) -> Bool {
        // macOS: /private/tmp and /tmp are the same directory (symlinked)
        path.hasPrefix("/private/tmp/claude-") || path.hasPrefix("/tmp/claude-")
    }

    private func isInAllowedDeletionScope(_ path: String) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return isClaudeTmpPath(path) || path.hasPrefix("\(home)/.claude/projects/")
    }

    // MARK: - Private

    private func startTimer() {
        timer?.invalidate()
        let interval = TimeInterval(scanIntervalSeconds)
        nextScanTime = Date().addingTimeInterval(interval)
        let newTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.scan()
            }
        }
        newTimer.tolerance = interval * 0.1
        timer = newTimer
    }

    private func restartTimer() {
        startTimer()
    }

    private func startFSEvents() {
        let claudeProjectsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects").path
        let watchedPaths = ["/private/tmp", claudeProjectsPath] as CFArray

        // passUnretained is safe: MonitorService is a singleton owned by AppDelegate
        // for the entire app lifetime. The stream is always stopped before dealloc (deinit).
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, _, eventPaths, _, _ in
            guard let info = info else { return }
            let monitor = Unmanaged<MonitorService>.fromOpaque(info).takeUnretainedValue()

            guard let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as? [String] else { return }
            let relevant = paths.contains { $0.contains("/claude-") || $0.contains("/.claude/projects/") }
            guard relevant else { return }

            Task { @MainActor in
                monitor.scheduleDebouncedScan()
            }
        }

        // NoDefer: first event after a quiet period delivers immediately; subsequent
        // events still coalesce within the 2.0s latency window. Combined with the 0.5s
        // debounce in scheduleDebouncedScan(), worst-case detection latency is ~2.5s.
        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            watchedPaths,
            FSEventsGetCurrentEventId(),
            2.0,
            UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer)
        ) else { return }

        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
        eventStream = stream
    }

    private func stopFSEvents() {
        guard let stream = eventStream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        eventStream = nil
    }

    private func scheduleDebouncedScan() {
        debouncedScanTask?.cancel()
        debouncedScanTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            guard !Task.isCancelled else { return }
            self?.scan()
        }
    }

    private func scan() {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }

        let fm = FileManager.default
        let tmpDir = "/private/tmp"
        let scanTime = Date()
        var foundProjects: [ClaudeProject] = []
        var currentPaths: Set<String> = []

        guard let tmpContents = try? fm.contentsOfDirectory(atPath: tmpDir) else { return }
        let claudeDirs = tmpContents.filter { $0.hasPrefix("claude-") }

        for claudeDir in claudeDirs {
            let claudePath = "\(tmpDir)/\(claudeDir)"
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: claudePath, isDirectory: &isDir), isDir.boolValue else { continue }

            // Validate resolved path is still under /private/tmp/claude- or /tmp/claude-
            guard let realClaudePath = try? resolveRealPath(claudePath),
                  isClaudeTmpPath(realClaudePath) else { continue }

            guard let projectDirs = try? fm.contentsOfDirectory(atPath: claudePath) else { continue }

            for projectDir in projectDirs {
                let projectPath = "\(claudePath)/\(projectDir)"
                guard fm.fileExists(atPath: projectPath, isDirectory: &isDir), isDir.boolValue else { continue }

                let (rawFiles, projectTotalSize) = scanDirectory(projectPath, fm: fm)
                guard !rawFiles.isEmpty else { continue }

                // Compute growth rates by comparing to previous scan
                let files = rawFiles.map { file -> MonitoredFile in
                    var rate: Double? = nil
                    if let prev = previousSizes[file.resolvedPath] {
                        let delta = Double(file.size) - Double(prev.size)
                        if delta > 0 {
                            let timeDelta = scanTime.timeIntervalSince(prev.time)
                            if timeDelta > 0 {
                                rate = delta / timeDelta
                            }
                        }
                    }
                    return MonitoredFile(
                        path: file.path,
                        resolvedPath: file.resolvedPath,
                        isSymlink: file.isSymlink,
                        isBrokenSymlink: file.isBrokenSymlink,
                        isTargetInScope: file.isTargetInScope,
                        size: file.size,
                        lastModified: file.lastModified,
                        name: file.name,
                        growthRate: rate,
                        duplicateCount: 1
                    )
                }

                for file in files { currentPaths.insert(file.path) }

                let lastMod = files.map(\.lastModified).max() ?? Date.distantPast
                let staleThreshold = TimeInterval(staleDaysThreshold * 86400)
                let isStale = Date().timeIntervalSince(lastMod) > staleThreshold

                let project = ClaudeProject(
                    path: projectPath,
                    name: projectDir,
                    displayName: extractProjectName(from: projectDir),
                    totalSize: projectTotalSize,
                    files: files.sorted { $0.size > $1.size },
                    lastModified: lastMod,
                    isStale: isStale,
                    claudeDir: claudeDir
                )
                foundProjects.append(project)
            }
        }

        // Compute cross-project duplicate counts (files sharing the same resolved path)
        var resolvedPathCounts: [String: Int] = [:]
        for project in foundProjects {
            for file in project.files where !file.isBrokenSymlink {
                resolvedPathCounts[file.resolvedPath, default: 0] += 1
            }
        }
        let hasDuplicates = resolvedPathCounts.values.contains { $0 > 1 }
        if hasDuplicates {
            foundProjects = foundProjects.map { project in
                ClaudeProject(
                    path: project.path,
                    name: project.name,
                    displayName: project.displayName,
                    totalSize: project.totalSize,
                    files: project.files.map { file in
                        let count = file.isBrokenSymlink ? 1 : (resolvedPathCounts[file.resolvedPath] ?? 1)
                        guard count != file.duplicateCount else { return file }
                        return MonitoredFile(
                            path: file.path,
                            resolvedPath: file.resolvedPath,
                            isSymlink: file.isSymlink,
                            isBrokenSymlink: file.isBrokenSymlink,
                            isTargetInScope: file.isTargetInScope,
                            size: file.size,
                            lastModified: file.lastModified,
                            name: file.name,
                            growthRate: file.growthRate,
                            duplicateCount: count
                        )
                    },
                    lastModified: project.lastModified,
                    isStale: project.isStale,
                    claudeDir: project.claudeDir
                )
            }
        }

        projects = foundProjects.sorted { $0.totalSize > $1.totalSize }
        totalSize = projects.reduce(0) { $0 + $1.totalSize }
        totalFileCount = projects.reduce(0) { $0 + $1.files.count }
        lastScanTime = scanTime

        // Rebuild previousSizes from current scan (implicitly prunes stale entries).
        // Carry forward the previous timestamp when size hasn't changed, so that
        // growth rates after idle periods reflect actual growth duration, not idle time.
        var newPreviousSizes: [String: (size: UInt64, time: Date)] = [:]
        for project in projects {
            for file in project.files {
                if let prev = previousSizes[file.resolvedPath], prev.size == file.size {
                    newPreviousSizes[file.resolvedPath] = prev
                } else {
                    newPreviousSizes[file.resolvedPath] = (file.size, scanTime)
                }
            }
        }
        previousSizes = newPreviousSizes

        // Prune notifiedPaths to only contain paths that still exist
        notifiedPaths.formIntersection(currentPaths)

        updateStatus()

        // Notify history service (or any other listener) of scan results
        onScanComplete?(totalSize, totalFileCount, projects)

        // Reset fallback timer after every scan (regardless of trigger source)
        restartTimer()
    }

    private func resolveRealPath(_ path: String) throws -> String {
        let url = URL(fileURLWithPath: path)
        return url.resolvingSymlinksInPath().path
    }

    private func scanDirectory(_ path: String, fm: FileManager) -> ([MonitoredFile], UInt64) {
        var files: [MonitoredFile] = []
        var totalSize: UInt64 = 0
        var seenResolvedPaths: Set<String> = []

        guard let enumerator = fm.enumerator(atPath: path) else { return ([], 0) }

        while let relativePath = enumerator.nextObject() as? String {
            let fullPath = "\(path)/\(relativePath)"

            // Check if it's a symlink
            guard let attrs = try? fm.attributesOfItem(atPath: fullPath) else { continue }
            let fileType = attrs[.type] as? FileAttributeType

            // Skip directories
            if fileType == .typeDirectory { continue }

            var resolvedPath = fullPath
            var isSymlink = false
            var isBrokenSymlink = false

            if fileType == .typeSymbolicLink {
                isSymlink = true
                if let target = try? fm.destinationOfSymbolicLink(atPath: fullPath) {
                    // Resolve relative symlinks relative to the symlink's parent directory
                    let parentDir = (fullPath as NSString).deletingLastPathComponent
                    resolvedPath = target.hasPrefix("/") ? target : "\(parentDir)/\(target)"
                    if !fm.fileExists(atPath: resolvedPath) {
                        isBrokenSymlink = true
                    }
                } else {
                    isBrokenSymlink = true
                }
            }

            // Get size from the actual file (not symlink)
            var fileSize: UInt64 = 0
            var modDate = Date.distantPast

            if !isBrokenSymlink {
                if let resolvedAttrs = try? fm.attributesOfItem(atPath: resolvedPath) {
                    fileSize = resolvedAttrs[.size] as? UInt64 ?? 0
                    modDate = resolvedAttrs[.modificationDate] as? Date ?? Date.distantPast
                }
            }

            // Non-symlinks are always in scope (they live in /private/tmp/claude-*).
            // Broken symlinks have no target — removing the dangling entry is always safe.
            let targetInScope = !isSymlink || isBrokenSymlink || isInAllowedDeletionScope(resolvedPath)

            let file = MonitoredFile(
                path: fullPath,
                resolvedPath: resolvedPath,
                isSymlink: isSymlink,
                isBrokenSymlink: isBrokenSymlink,
                isTargetInScope: targetInScope,
                size: fileSize,
                lastModified: modDate,
                name: (fullPath as NSString).lastPathComponent,
                growthRate: nil,
                duplicateCount: 1
            )
            files.append(file)

            // Avoid double-counting files pointed to by multiple symlinks
            if !seenResolvedPaths.contains(resolvedPath) {
                seenResolvedPaths.insert(resolvedPath)
                totalSize += fileSize
            }
        }

        return (files, totalSize)
    }

    private func updateStatus() {
        let wBytes = warningBytes
        let cBytes = criticalBytes

        let largestFile = projects.flatMap(\.files).max(by: { $0.size < $1.size })
        let largestSize = largestFile?.size ?? 0

        var newStatus: MonitorStatus = .normal

        if largestSize >= cBytes || totalSize >= cBytes {
            newStatus = .critical
        } else if largestSize >= wBytes || totalSize >= wBytes {
            newStatus = .warning
        }

        // Send notifications for individual large files
        for project in projects {
            for file in project.files {
                guard !notifiedPaths.contains(file.path) else { continue }

                if file.size >= cBytes {
                    sendNotification(
                        title: "Critical: \(formatBytes(file.size)) file detected",
                        body: "\(project.displayName)/\(file.name)"
                    )
                    notifiedPaths.insert(file.path)
                } else if file.size >= wBytes {
                    sendNotification(
                        title: "Warning: \(formatBytes(file.size)) file growing",
                        body: "\(project.displayName)/\(file.name)"
                    )
                    notifiedPaths.insert(file.path)
                }
            }
        }

        status = newStatus
    }

    private func extractProjectName(from dirName: String) -> String {
        // Convert "-Users-esison-Development-personal-LeadProspector" to "LeadProspector"
        // Take the last meaningful segment after splitting by "-"
        let cleaned = dirName.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let segments = cleaned.split(separator: "-").map(String.init)

        // Find the last segment that isn't a common path component
        let skipWords: Set<String> = ["Users", "Development", "personal", "hardware", "esison"]
        let meaningful = segments.filter { !skipWords.contains($0) }
        if let last = meaningful.last, !last.isEmpty {
            return last
        }
        // Fallback: last two segments
        if segments.count >= 2 {
            return segments.suffix(2).joined(separator: "/")
        }
        return dirName
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func checkNotificationAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.notificationsDenied = settings.authorizationStatus == .denied
            }
        }
    }

    private func sendNotification(title: String, body: String) {
        guard notificationsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Byte Formatting

func formatBytes(_ bytes: UInt64) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(clamping: bytes), countStyle: .file)
}

func formatGrowthRate(_ bytesPerSecond: Double) -> String? {
    guard bytesPerSecond.isFinite, bytesPerSecond > 0 else { return nil }
    let bytesPerMinute = bytesPerSecond * 60
    guard bytesPerMinute >= 1024 else { return nil } // suppress sub-1 KB/min noise
    let formatted = ByteCountFormatter.string(
        fromByteCount: Int64(clamping: Int(bytesPerMinute)),
        countStyle: .file
    )
    return "\(formatted)/min"
}
