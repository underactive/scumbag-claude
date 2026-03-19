import SwiftUI

// MARK: - Delete Confirmation

enum DeleteConfirmation: Equatable {
    case file(String)
    case project(String)
    case all
    case brokenSymlinks
    case selectedFiles
}

private enum ProjectSortOrder: String, CaseIterable {
    case size = "Size"
    case name = "Name"
    case date = "Date"
}

// MARK: - Hover Button Style

/// A plain button style that shows a subtle rounded background on hover.
/// Used for icon-only buttons (refresh, chevron) that should not look bordered.
private struct HoverButtonStyle: ButtonStyle {
    var hoverColor: Color = .primary

    func makeBody(configuration: Configuration) -> some View {
        HoverButtonBody(configuration: configuration, hoverColor: hoverColor)
    }
}

private struct HoverButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let hoverColor: Color
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? hoverColor.opacity(0.1) : Color.clear)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .onHover { isHovered = $0 }
    }
}

// MARK: - Scan Timer View

/// Shows a pie chart that empties as the next scan approaches, switching to a spinner
/// for the last 2 seconds of the interval.
private struct ScanTimerView: View {
    let nextScanTime: Date
    let scanInterval: TimeInterval

    @State private var fraction: CGFloat = 1.0
    @State private var showSpinner = false

    private let tickTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if showSpinner {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
            } else {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1.5)
                    PieSlice(fraction: fraction)
                        .fill(Color.secondary.opacity(0.4))
                }
            }
        }
        .frame(width: 12, height: 12)
        .onReceive(tickTimer) { _ in
            updateFraction()
        }
        .onAppear {
            updateFraction()
        }
    }

    private func updateFraction() {
        let remaining = nextScanTime.timeIntervalSinceNow
        if remaining <= 1 {
            showSpinner = true
            fraction = 0
        } else {
            showSpinner = false
            fraction = max(0, min(1, remaining / scanInterval))
        }
    }
}

/// A pie slice shape drawn clockwise from 12 o'clock.
private struct PieSlice: Shape {
    var fraction: CGFloat

    var animatableData: CGFloat {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard fraction > 0 else { return Path() }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let startAngle = Angle(degrees: -90)
        let endAngle = Angle(degrees: -90 - 360 * Double(fraction))
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        path.closeSubpath()
        return path
    }
}

// MARK: - Pulsing Dot

private struct PulsingDot: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(Color.green)
            .frame(width: 6, height: 6)
            .opacity(isPulsing ? 1.0 : 0.4)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
            .onDisappear { isPulsing = false }
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @EnvironmentObject var monitor: MonitorService
    @EnvironmentObject var updateService: UpdateService
    @EnvironmentObject var historyService: HistoryService
    @State private var expandedProjects: Set<String> = []
    @State private var confirmDelete: DeleteConfirmation? = nil
    @State private var projectsContentHeight: CGFloat = 0
    @State private var searchQuery: String = ""
    @State private var sortOrder: ProjectSortOrder = .size
    @State private var selectedFiles: Set<String> = []
    var onOpenSettings: () -> Void = {}
    var onOpenStats: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider()
            statusSection
            Divider()

            if monitor.projects.isEmpty {
                emptySection
            } else {
                searchSortBar
                if displayedProjects.isEmpty {
                    noMatchesSection
                } else {
                    projectsSection
                }
            }

            if updateService.shouldShowBanner || updateService.status.isActiveUpdate {
                Divider()
                updateBannerSection
            }

            Divider()
            footerSection
        }
        .frame(width: 380)
        .onAppear {
            confirmDelete = nil
            searchQuery = ""
            selectedFiles = []
        }
        .onChange(of: searchQuery) { _ in confirmDelete = nil }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Image(systemName: "externaldrive.badge.timemachine")
                .foregroundColor(.secondary)
            Text("Scumbag Claude")
                .font(.headline)
            Spacer()
            Button(action: { monitor.scanNow() }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(HoverButtonStyle())
            .disabled(monitor.isScanning)
            .accessibilityLabel("Refresh")
            .keyboardShortcut("r", modifiers: .command)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Status

    private var statusSection: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(monitor.status.rawValue)
                .font(.subheadline.weight(.medium))
                .foregroundColor(statusColor)
            Text("·")
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            Text(formatBytes(monitor.totalSize))
                .font(.subheadline)
            Text("·")
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            Text("\(monitor.totalFileCount) \(monitor.totalFileCount == 1 ? "file" : "files")")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            if let nextScan = monitor.nextScanTime {
                ScanTimerView(
                    nextScanTime: nextScan,
                    scanInterval: TimeInterval(monitor.scanIntervalSeconds)
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var statusColor: Color {
        switch monitor.status {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }

    // MARK: - Empty State

    private var emptySection: some View {
        VStack(spacing: 4) {
            Text("No Claude tmp directories found")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("/private/tmp/claude-*/")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Search & Sort

    private var searchSortBar: some View {
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Filter projects...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.06))
            .cornerRadius(6)

            Menu {
                ForEach(ProjectSortOrder.allCases, id: \.self) { order in
                    Button(action: { sortOrder = order }) {
                        if sortOrder == order {
                            Label(order.rawValue, systemImage: "checkmark")
                        } else {
                            Text(order.rawValue)
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("Sort order")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var noMatchesSection: some View {
        Text("No matching projects")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
    }

    // MARK: - Projects List

    private static let maxProjectsHeight: CGFloat = 300

    private var projectsSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(displayedProjects) { project in
                    VStack(alignment: .leading, spacing: 0) {
                        projectRow(project)
                        if expandedProjects.contains(project.id) {
                            filesSection(for: project)
                        }
                    }
                }
            }
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: ProjectsHeightKey.self, value: geo.size.height)
                }
            )
        }
        .frame(height: min(max(projectsContentHeight, 1), Self.maxProjectsHeight))
        .onPreferenceChange(ProjectsHeightKey.self) { projectsContentHeight = $0 }
    }

    private func projectRow(_ project: ClaudeProject) -> some View {
        HStack(spacing: 8) {
            Button(action: { toggleProject(project.id) }) {
                Image(systemName: expandedProjects.contains(project.id) ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 12)
            }
            .buttonStyle(HoverButtonStyle())
            .accessibilityLabel(expandedProjects.contains(project.id) ? "Collapse project" : "Expand project")

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(project.displayName)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    if project.isStale && !project.isActive {
                        Text("stale")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(3)
                    }
                    if project.isActive {
                        HStack(spacing: 3) {
                            PulsingDot()
                            Text("live")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(3)
                        .help("Claude Code is actively writing to this project")
                    }
                }
                HStack(spacing: 0) {
                    Text("\(project.files.count) \(project.files.count == 1 ? "file" : "files")")
                    if project.brokenSymlinkCount > 0 {
                        Text(" · ")
                        Text("\(project.brokenSymlinkCount) broken")
                            .foregroundColor(.red)
                    }
                    Text(" · \(project.claudeDir)")
                    if project.lastModified != .distantPast {
                        Text(" · \(relativeTime(project.lastModified))")
                    }
                    if let rateText = formatGrowthRate(project.growthRate) {
                        Text(" · ")
                        Text("↑ \(rateText)")
                            .foregroundColor(.orange)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }

            Spacer()

            Text(formatBytes(project.totalSize))
                .font(.subheadline.monospacedDigit())
                .foregroundColor(sizeColor(project.totalSize))

            if confirmDelete == .project(project.id) {
                Button("Cancel") { confirmDelete = nil }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                Button("Delete") {
                    selectedFiles.subtract(project.files.map(\.id))
                    monitor.deleteProject(project)
                    confirmDelete = nil
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .tint(.red)
            } else {
                Button(action: { confirmDelete = .project(project.id) }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(HoverButtonStyle(hoverColor: .red))
                .accessibilityLabel("Delete project")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture { toggleProject(project.id) }
    }

    private func filesSection(for project: ClaudeProject) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(sortedFiles(project.files)) { file in
                fileRow(file)
            }
        }
        .padding(.leading, 16)
    }

    private func fileRow(_ file: MonitoredFile) -> some View {
        HStack(spacing: 4) {
            Button(action: { toggleFileSelection(file.id) }) {
                Image(systemName: selectedFiles.contains(file.id) ? "checkmark.circle.fill" : "circle")
                    .font(.caption2)
                    .foregroundColor(selectedFiles.contains(file.id) ? .accentColor : .secondary.opacity(0.4))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(selectedFiles.contains(file.id) ? "Deselect file" : "Select file")

            Image(systemName: file.isSymlink ? "link" : "doc")
                .font(.caption2)
                .foregroundColor(file.isBrokenSymlink ? .red : .secondary)
                .frame(width: 12)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 3) {
                    Text(file.name)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if file.duplicateCount > 1 {
                        Text("×\(file.duplicateCount)")
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.blue)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 0.5)
                            .background(Color.blue.opacity(0.12))
                            .cornerRadius(3)
                            .help("\(file.duplicateCount) symlinks share this target — size counted once")
                    }
                }
                if file.isBrokenSymlink {
                    Text("broken symlink")
                        .font(.caption2)
                        .foregroundColor(.red)
                } else if file.isSymlink {
                    HStack(spacing: 3) {
                        Text("→ \((file.resolvedPath as NSString).lastPathComponent)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        if !file.isTargetInScope {
                            Text("link only")
                                .font(.caption2)
                                .foregroundColor(.purple)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 0.5)
                                .background(Color.purple.opacity(0.12))
                                .cornerRadius(3)
                                .help("Target is outside cleanup scope — delete removes only this symlink")
                        }
                    }
                }
            }

            Spacer()

            if !file.isBrokenSymlink {
                Text(formatBytes(file.size))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(sizeColor(file.size))
                Text(relativeTime(file.lastModified))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if let rate = file.growthRate, let rateText = formatGrowthRate(rate) {
                Text("↑ \(rateText)")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.orange)
            }

            if confirmDelete == .file(file.id) {
                Button("Cancel") { confirmDelete = nil }
                    .font(.caption2)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                Button("Delete") {
                    monitor.deleteFile(file)
                    selectedFiles.remove(file.id)
                    confirmDelete = nil
                }
                .font(.caption2)
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .tint(.red)
            } else {
                Button(action: { confirmDelete = .file(file.id) }) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(HoverButtonStyle(hoverColor: .red))
                .accessibilityLabel("Delete file")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
    }

    // MARK: - Update Banner

    private var updateBannerSection: some View {
        Group {
            switch updateService.status {
            case .available(let version, _, _):
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.accentColor)
                    Text("v\(version) available")
                        .font(.subheadline)
                    Spacer()
                    Button("Update") {
                        updateService.downloadUpdate()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(.subheadline)
                    Button(action: { updateService.dismissUpdate() }) {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(HoverButtonStyle())
                    .accessibilityLabel("Dismiss update")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.08))

            case .downloading(let progress):
                HStack(spacing: 8) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                    Text("\(Int(progress * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(width: 32, alignment: .trailing)
                    Button("Cancel") { updateService.cancelDownload() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .font(.subheadline)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            case .readyToInstall:
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Ready to install")
                        .font(.subheadline)
                    Spacer()
                    Button("Install & Restart") {
                        updateService.installUpdate()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(.subheadline)
                    .tint(.accentColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            case .installing:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Installing...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            case .error(let message):
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)
                    Spacer()
                    Button("Retry") {
                        Task { await updateService.checkForUpdates(manual: true) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(.subheadline)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            default:
                EmptyView()
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 4) {
            if let error = monitor.lastDeleteError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
            }

            HStack {
                Button(action: { onOpenSettings() }) {
                    Image(systemName: "gear")
                    Text("Settings")
                        .font(.subheadline)
                }
                .accessibilityLabel("Settings")
                .keyboardShortcut(",", modifiers: .command)

                Button(action: { onOpenStats() }) {
                    Image(systemName: "chart.xyaxis.line")
                    Text("Stats")
                        .font(.subheadline)
                }
                .accessibilityLabel("Statistics")

                Spacer()

                if selectedFileCount > 0 {
                    if confirmDelete == .selectedFiles {
                        Button("Cancel") { confirmDelete = nil }
                            .font(.caption)
                        Button("Confirm") {
                            let files = monitor.projects.flatMap(\.files).filter { selectedFiles.contains($0.id) }
                            monitor.deleteFiles(files)
                            selectedFiles = []
                            confirmDelete = nil
                        }
                        .font(.caption)
                        .tint(.red)
                    } else {
                        Button(action: { confirmDelete = .selectedFiles }) {
                            Text("Delete (\(selectedFileCount))")
                                .font(.subheadline)
                        }
                        .tint(.orange)
                    }
                }

                if brokenSymlinkCount > 0 {
                    if confirmDelete == .brokenSymlinks {
                        Button("Cancel") { confirmDelete = nil }
                            .font(.caption)
                        Button("Confirm") {
                            monitor.deleteBrokenSymlinks()
                            confirmDelete = nil
                        }
                        .font(.caption)
                        .tint(.red)
                    } else {
                        Button(action: { confirmDelete = .brokenSymlinks }) {
                            Text("Clean Broken (\(brokenSymlinkCount))")
                                .font(.subheadline)
                        }
                        .tint(.red)
                    }
                }

                if !monitor.projects.isEmpty {
                    if confirmDelete == .all {
                        Button("Cancel") { confirmDelete = nil }
                            .font(.caption)
                        Button("Confirm") {
                            monitor.deleteAllProjects()
                            selectedFiles = []
                            confirmDelete = nil
                        }
                        .font(.caption)
                        .tint(.red)
                    } else {
                        Button(action: { confirmDelete = .all }) {
                            Text("Clean All")
                                .font(.subheadline)
                        }
                        .tint(.orange)
                    }
                }

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.subheadline)
                .keyboardShortcut("q", modifiers: .command)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Helpers

    private func toggleProject(_ id: String) {
        if expandedProjects.contains(id) {
            expandedProjects.remove(id)
        } else {
            expandedProjects.insert(id)
        }
    }

    private var brokenSymlinkCount: Int {
        monitor.projects.reduce(0) { $0 + $1.brokenSymlinkCount }
    }

    private var displayedProjects: [ClaudeProject] {
        let filtered = searchQuery.isEmpty
            ? monitor.projects
            : monitor.projects.filter { $0.displayName.localizedCaseInsensitiveContains(searchQuery) }
        switch sortOrder {
        case .size: return filtered.sorted { $0.totalSize > $1.totalSize }
        case .name: return filtered.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        case .date: return filtered.sorted {
            if $0.lastModified == $1.lastModified {
                return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            return $0.lastModified > $1.lastModified
        }
        }
    }

    private func sortedFiles(_ files: [MonitoredFile]) -> [MonitoredFile] {
        switch sortOrder {
        case .size: return files.sorted { $0.size > $1.size }
        case .name: return files.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .date: return files.sorted {
            if $0.lastModified == $1.lastModified {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return $0.lastModified > $1.lastModified
        }
        }
    }

    private func toggleFileSelection(_ id: String) {
        if selectedFiles.contains(id) {
            selectedFiles.remove(id)
        } else {
            selectedFiles.insert(id)
        }
    }

    private var selectedFileCount: Int {
        let currentIds = Set(monitor.projects.flatMap(\.files).map(\.id))
        return selectedFiles.intersection(currentIds).count
    }

    private func sizeColor(_ bytes: UInt64) -> Color {
        if bytes >= monitor.criticalBytes { return .red }
        if bytes >= monitor.warningBytes { return .orange }
        return .primary
    }
}

// MARK: - Preference Keys

private struct ProjectsHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
