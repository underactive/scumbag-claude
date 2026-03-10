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
}

// MARK: - Models

struct MonitoredFile: Identifiable {
    var id: String { path }
    let path: String
    let resolvedPath: String
    let isSymlink: Bool
    let isBrokenSymlink: Bool
    let size: UInt64
    let lastModified: Date
    let name: String
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

    private var timer: Timer?
    private var notifiedPaths: Set<String> = []
    private var isUpdatingLaunchAtLogin = false

    init() {
        let defaults = UserDefaults.standard

        let rawWarning = defaults.object(forKey: SettingsKey.warningThresholdMB) as? Int ?? 100
        self.warningThresholdMB = min(max(rawWarning, 10), 1000000)

        let rawCritical = defaults.object(forKey: SettingsKey.criticalThresholdMB) as? Int ?? 500
        self.criticalThresholdMB = min(max(rawCritical, 50), 1000000)

        let rawInterval = defaults.object(forKey: SettingsKey.scanIntervalSeconds) as? Int ?? 30
        self.scanIntervalSeconds = min(max(rawInterval, 5), 300)

        let rawStale = defaults.object(forKey: SettingsKey.staleDaysThreshold) as? Int ?? 7
        self.staleDaysThreshold = min(max(rawStale, 1), 90)

        self.notificationsEnabled = defaults.object(forKey: SettingsKey.notificationsEnabled) as? Bool ?? true
        self.showSizeInMenuBar = defaults.object(forKey: SettingsKey.showSizeInMenuBar) as? Bool ?? true
        self.launchAtLogin = SMAppService.mainApp.status == .enabled

        requestNotificationPermission()
        checkNotificationAuthorization()
        startTimer()

        Task { @MainActor in
            self.scan()
        }
    }

    deinit {
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

    private func scan() {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }

        let fm = FileManager.default
        let tmpDir = "/private/tmp"
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

                let (files, projectTotalSize) = scanDirectory(projectPath, fm: fm)
                guard !files.isEmpty else { continue }

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

        projects = foundProjects.sorted { $0.totalSize > $1.totalSize }
        totalSize = projects.reduce(0) { $0 + $1.totalSize }
        totalFileCount = projects.reduce(0) { $0 + $1.files.count }
        lastScanTime = Date()

        // Prune notifiedPaths to only contain paths that still exist
        notifiedPaths.formIntersection(currentPaths)

        updateStatus()
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

            let file = MonitoredFile(
                path: fullPath,
                resolvedPath: resolvedPath,
                isSymlink: isSymlink,
                isBrokenSymlink: isBrokenSymlink,
                size: fileSize,
                lastModified: modDate,
                name: (fullPath as NSString).lastPathComponent
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
