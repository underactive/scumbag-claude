import Foundation
import ServiceManagement
import UserNotifications

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

    var isOutputFile: Bool { name.hasSuffix(".output") }

    var effectiveSize: UInt64 {
        isBrokenSymlink ? 0 : size
    }
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

    var iconName: String {
        switch self {
        case .normal: return "externaldrive"
        case .warning: return "exclamationmark.triangle"
        case .critical: return "exclamationmark.triangle.fill"
        }
    }
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

    // Settings
    @Published var warningThresholdMB: Int {
        didSet { UserDefaults.standard.set(warningThresholdMB, forKey: "warningThresholdMB") }
    }
    @Published var criticalThresholdMB: Int {
        didSet { UserDefaults.standard.set(criticalThresholdMB, forKey: "criticalThresholdMB") }
    }
    @Published var scanIntervalSeconds: Int {
        didSet {
            UserDefaults.standard.set(scanIntervalSeconds, forKey: "scanIntervalSeconds")
            restartTimer()
        }
    }
    @Published var staleDaysThreshold: Int {
        didSet { UserDefaults.standard.set(staleDaysThreshold, forKey: "staleDaysThreshold") }
    }
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Revert on failure
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    var statusIcon: String { status.iconName }

    private var timer: Timer?
    private var notifiedPaths: Set<String> = []

    init() {
        let defaults = UserDefaults.standard
        self.warningThresholdMB = defaults.object(forKey: "warningThresholdMB") as? Int ?? 100
        self.criticalThresholdMB = defaults.object(forKey: "criticalThresholdMB") as? Int ?? 500
        self.scanIntervalSeconds = defaults.object(forKey: "scanIntervalSeconds") as? Int ?? 30
        self.staleDaysThreshold = defaults.object(forKey: "staleDaysThreshold") as? Int ?? 7
        self.notificationsEnabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true
        self.launchAtLogin = SMAppService.mainApp.status == .enabled

        requestNotificationPermission()
        scan()
        startTimer()
    }

    func scanNow() {
        scan()
    }

    func deleteFile(_ file: MonitoredFile) {
        let fm = FileManager.default
        // If symlink, delete the target first to reclaim space
        if file.isSymlink && !file.isBrokenSymlink {
            try? fm.removeItem(atPath: file.resolvedPath)
        }
        // Delete the entry (symlink or actual file)
        try? fm.removeItem(atPath: file.path)
        notifiedPaths.remove(file.path)
        scan()
    }

    func deleteProject(_ project: ClaudeProject) {
        let fm = FileManager.default
        // Delete symlink targets first to reclaim space from resolved locations
        for file in project.files where file.isSymlink && !file.isBrokenSymlink {
            try? fm.removeItem(atPath: file.resolvedPath)
        }
        // Delete the entire project directory
        try? fm.removeItem(atPath: project.path)
        for file in project.files {
            notifiedPaths.remove(file.path)
        }
        scan()
    }

    // MARK: - Private

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(scanIntervalSeconds), repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.scan()
            }
        }
    }

    private func restartTimer() {
        startTimer()
    }

    private func scan() {
        isScanning = true
        defer { isScanning = false }

        let fm = FileManager.default
        let tmpDir = "/private/tmp"
        var foundProjects: [ClaudeProject] = []

        guard let tmpContents = try? fm.contentsOfDirectory(atPath: tmpDir) else { return }
        let claudeDirs = tmpContents.filter { $0.hasPrefix("claude-") }

        for claudeDir in claudeDirs {
            let claudePath = "\(tmpDir)/\(claudeDir)"
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: claudePath, isDirectory: &isDir), isDir.boolValue else { continue }
            guard let projectDirs = try? fm.contentsOfDirectory(atPath: claudePath) else { continue }

            for projectDir in projectDirs {
                let projectPath = "\(claudePath)/\(projectDir)"
                guard fm.fileExists(atPath: projectPath, isDirectory: &isDir), isDir.boolValue else { continue }

                let (files, projectTotalSize) = scanDirectory(projectPath, fm: fm)
                guard !files.isEmpty else { continue }

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

        updateStatus()
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
                    resolvedPath = target.hasPrefix("/") ? target : "\(path)/\(target)"
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
        let warningBytes = UInt64(warningThresholdMB) * 1024 * 1024
        let criticalBytes = UInt64(criticalThresholdMB) * 1024 * 1024

        let largestFile = projects.flatMap(\.files).max(by: { $0.size < $1.size })
        let largestSize = largestFile?.size ?? 0

        var newStatus: MonitorStatus = .normal

        if largestSize >= criticalBytes || totalSize >= criticalBytes {
            newStatus = .critical
        } else if largestSize >= warningBytes || totalSize >= warningBytes {
            newStatus = .warning
        }

        // Send notifications for individual large files
        for project in projects {
            for file in project.files {
                guard !notifiedPaths.contains(file.path) else { continue }

                if file.size >= criticalBytes {
                    sendNotification(
                        title: "Critical: \(formatBytes(file.size)) file detected",
                        body: "\(project.displayName)/\(file.name)"
                    )
                    notifiedPaths.insert(file.path)
                } else if file.size >= warningBytes {
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
