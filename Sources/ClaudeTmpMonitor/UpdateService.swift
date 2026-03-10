import Foundation
import AppKit

// MARK: - Update Status

enum UpdateStatus: Equatable {
    case idle
    case checking
    case available(version: String, downloadURL: URL, releaseNotes: String?)
    case downloading(progress: Double)
    case readyToInstall(appPath: URL)
    case installing
    case upToDate
    case error(String)

    var isActiveUpdate: Bool {
        switch self {
        case .downloading, .readyToInstall, .installing, .error:
            return true
        default:
            return false
        }
    }
}

// MARK: - Update Service

@MainActor
class UpdateService: ObservableObject {
    @Published var status: UpdateStatus = .idle

    @Published var checkForUpdatesAutomatically: Bool {
        didSet {
            guard !isInitializing else { return }
            UserDefaults.standard.set(checkForUpdatesAutomatically, forKey: SettingsKey.checkForUpdatesAutomatically)
            if checkForUpdatesAutomatically {
                startTimer()
            } else {
                timer?.invalidate()
                timer = nil
            }
        }
    }

    private var dismissedVersion: String?

    private var lastCheckTime: Date?

    private let updateCheckInterval: TimeInterval = 24 * 3600
    private let apiTimeoutSeconds: TimeInterval = 15
    private let githubAPIURL = URL(string: "https://api.github.com/repos/underactive/scumbag-claude/releases/latest")!

    private var timer: Timer?
    private var downloadTask: Task<Void, Never>?
    private var progressDelegate: DownloadProgressDelegate?
    private var isInitializing = true

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    var shouldShowBanner: Bool {
        if case .available(let version, _, _) = status {
            return version != dismissedVersion
        }
        return false
    }

    init() {
        let defaults = UserDefaults.standard
        self.checkForUpdatesAutomatically = defaults.object(forKey: SettingsKey.checkForUpdatesAutomatically) as? Bool ?? true
        self.dismissedVersion = defaults.string(forKey: SettingsKey.dismissedUpdateVersion)

        if let epoch = defaults.object(forKey: SettingsKey.lastUpdateCheckTime) as? TimeInterval {
            self.lastCheckTime = Date(timeIntervalSince1970: epoch)
        }

        isInitializing = false

        if checkForUpdatesAutomatically {
            startTimer()
            let shouldCheck = lastCheckTime.map { Date().timeIntervalSince($0) >= updateCheckInterval } ?? true
            if shouldCheck {
                Task { @MainActor in
                    await checkForUpdates(manual: false)
                }
            }
        }
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Public Methods

    func checkForUpdates(manual: Bool) async {
        guard status != .checking else { return }
        status = .checking

        do {
            let (remoteVersion, downloadURL, releaseNotes) = try await fetchLatestRelease()

            persistCheckTime()

            if compareVersions(remoteVersion, currentVersion) == .orderedDescending {
                status = .available(version: remoteVersion, downloadURL: downloadURL, releaseNotes: releaseNotes)
            } else {
                status = .upToDate
                // Auto-clear "up to date" after 3 seconds for automatic checks
                if !manual {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    if status == .upToDate { status = .idle }
                }
            }
        } catch is CancellationError {
            status = .idle
        } catch {
            if manual {
                status = .error(error.localizedDescription)
            } else {
                status = .idle
            }
        }
    }

    func downloadUpdate() {
        guard case .available(_, let downloadURL, _) = status else { return }

        // Validate download URL uses HTTPS
        guard downloadURL.scheme == "https" else {
            status = .error("Download URL is not secure (HTTPS required).")
            return
        }

        downloadTask = Task { @MainActor in
            await performDownload(from: downloadURL)
        }
    }

    func installUpdate() {
        guard case .readyToInstall(let newAppPath) = status else { return }

        let currentAppPath = Bundle.main.bundlePath
        let fm = FileManager.default

        guard currentAppPath.hasSuffix(".app") else {
            status = .error("Cannot auto-update when running from a development build. Please update manually.")
            return
        }

        guard fm.isWritableFile(atPath: (currentAppPath as NSString).deletingLastPathComponent) else {
            status = .error("Cannot write to \(currentAppPath). Please update manually or check permissions.")
            return
        }

        status = .installing

        let pid = ProcessInfo.processInfo.processIdentifier
        let expectedTempDir = fm.temporaryDirectory.appendingPathComponent("scumbag-claude-update").path

        // Use the known temp directory, not one derived from the downloaded app path
        let scriptURL = fm.temporaryDirectory.appendingPathComponent("scumbag-claude-updater-\(UUID().uuidString).sh")
        do {
            // Pass paths as positional arguments to avoid shell injection
            let script = """
            #!/bin/bash
            CURRENT_APP="$1"
            NEW_APP="$2"
            TEMP_DIR="$3"
            # Wait up to 30 seconds for the old process to exit
            for i in $(seq 1 30); do
                kill -0 \(pid) 2>/dev/null || break; sleep 1
            done
            rm -rf "$CURRENT_APP"
            cp -R "$NEW_APP" "$CURRENT_APP"
            xattr -cr "$CURRENT_APP"
            open "$CURRENT_APP"
            rm -rf "$TEMP_DIR"
            rm -f "$0"
            """

            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptURL.path, currentAppPath, newAppPath.path, expectedTempDir]
            try process.run()

            NSApp.terminate(nil)
        } catch {
            status = .error("Failed to launch updater: \(error.localizedDescription)")
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        progressDelegate = nil
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("scumbag-claude-update")
        try? FileManager.default.removeItem(at: tempDir)
        status = .idle
    }

    func dismissUpdate() {
        if case .available(let version, _, _) = status {
            dismissedVersion = version
            UserDefaults.standard.set(dismissedVersion, forKey: SettingsKey.dismissedUpdateVersion)
        }
        status = .idle
    }

    // MARK: - Private: Network

    private func fetchLatestRelease() async throws -> (version: String, downloadURL: URL, releaseNotes: String?) {
        var request = URLRequest(url: githubAPIURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = apiTimeoutSeconds

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw UpdateError.apiError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tagName = json["tag_name"] as? String,
              let assets = json["assets"] as? [[String: Any]],
              let firstAsset = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".zip") == true }),
              let downloadURLString = firstAsset["browser_download_url"] as? String,
              let downloadURL = URL(string: downloadURLString) else {
            throw UpdateError.parseError
        }

        let remoteVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
        let releaseNotes = json["body"] as? String

        return (remoteVersion, downloadURL, releaseNotes)
    }

    private func performDownload(from downloadURL: URL) async {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("scumbag-claude-update")
        let fm = FileManager.default

        try? fm.removeItem(at: tempDir)
        try? fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

        status = .downloading(progress: 0)

        // Store delegate as instance property to prevent premature deallocation
        let delegate = DownloadProgressDelegate { [weak self] progress in
            Task { @MainActor in
                self?.status = .downloading(progress: progress)
            }
        }
        self.progressDelegate = delegate

        do {
            let (tempURL, response) = try await URLSession.shared.download(from: downloadURL, delegate: delegate)

            self.progressDelegate = nil

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                try? fm.removeItem(at: tempDir)
                status = .error("Download failed: server returned an error.")
                return
            }

            let zipPath = tempDir.appendingPathComponent("update.zip")
            try fm.moveItem(at: tempURL, to: zipPath)

            let appBundle = try await extractAndFindApp(zipPath: zipPath, tempDir: tempDir)

            status = .readyToInstall(appPath: appBundle)
        } catch is CancellationError {
            try? fm.removeItem(at: tempDir)
            status = .idle
        } catch {
            try? fm.removeItem(at: tempDir)
            status = .error("Download failed: \(error.localizedDescription)")
        }
    }

    private func extractAndFindApp(zipPath: URL, tempDir: URL) async throws -> URL {
        // Run ditto on a background thread to avoid blocking the main thread
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let unzipProcess = Process()
                unzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                unzipProcess.arguments = ["-xk", zipPath.path, tempDir.path]
                do {
                    try unzipProcess.run()
                    unzipProcess.waitUntilExit()
                    if unzipProcess.terminationStatus == 0 {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: UpdateError.extractionFailed)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        let extractedContents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        guard let appBundle = extractedContents.first(where: { $0.pathExtension == "app" }) else {
            throw UpdateError.noAppInArchive
        }

        return appBundle
    }

    // MARK: - Private: Persistence

    private func persistCheckTime() {
        lastCheckTime = Date()
        UserDefaults.standard.set(lastCheckTime?.timeIntervalSince1970, forKey: SettingsKey.lastUpdateCheckTime)
    }

    // MARK: - Private: Version Comparison

    /// Compares two semantic version strings (e.g., "1.2.3" vs "1.3.0").
    /// Non-numeric segments are silently dropped (pre-release suffixes like "-beta" are ignored).
    private func compareVersions(_ a: String, _ b: String) -> ComparisonResult {
        let partsA = a.split(separator: ".").compactMap { Int($0) }
        let partsB = b.split(separator: ".").compactMap { Int($0) }
        let count = max(partsA.count, partsB.count)

        for i in 0..<count {
            let valA = i < partsA.count ? partsA[i] : 0
            let valB = i < partsB.count ? partsB[i] : 0
            if valA < valB { return .orderedAscending }
            if valA > valB { return .orderedDescending }
        }
        return .orderedSame
    }

    // MARK: - Private: Timer

    private func startTimer() {
        timer?.invalidate()
        let newTimer = Timer.scheduledTimer(withTimeInterval: updateCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkForUpdates(manual: false)
            }
        }
        newTimer.tolerance = updateCheckInterval * 0.1
        timer = newTimer
    }
}

// MARK: - Update Errors

private enum UpdateError: LocalizedError {
    case apiError
    case parseError
    case extractionFailed
    case noAppInArchive

    var errorDescription: String? {
        switch self {
        case .apiError: return "GitHub API returned an error. Try again later."
        case .parseError: return "Could not parse release information."
        case .extractionFailed: return "Failed to extract update archive."
        case .noAppInArchive: return "Update archive does not contain an application."
        }
    }
}

// MARK: - Download Progress Delegate

private final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate {
    private let onProgress: @Sendable (Double) -> Void
    private var lastReportedProgress: Double = -1

    init(onProgress: @escaping @Sendable (Double) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Handled by the async download call
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = min(max(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite), 0), 1)
        // Throttle: only report if progress changed by at least 1%
        let rounded = (progress * 100).rounded() / 100
        guard rounded != lastReportedProgress else { return }
        lastReportedProgress = rounded
        onProgress(progress)
    }
}
