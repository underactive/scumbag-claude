import SwiftUI

// MARK: - Delete Confirmation

enum DeleteConfirmation: Equatable {
    case file(String)
    case project(String)
    case all
}

// MARK: - Main Content View

struct ContentView: View {
    @EnvironmentObject var monitor: MonitorService
    @State private var showSettings = false
    @State private var expandedProjects: Set<String> = []
    @State private var confirmDelete: DeleteConfirmation? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider()
            statusSection
            Divider()

            if monitor.projects.isEmpty {
                emptySection
            } else {
                projectsSection
            }

            Divider()

            if showSettings {
                settingsSection
                Divider()
            }

            footerSection
        }
        .frame(width: 380)
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
            .buttonStyle(.plain)
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
            if let lastScan = monitor.lastScanTime {
                Text(lastScan, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
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

    // MARK: - Projects List

    private var projectsSection: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(monitor.projects) { project in
                    VStack(alignment: .leading, spacing: 0) {
                        projectRow(project)
                        if expandedProjects.contains(project.id) {
                            filesSection(for: project)
                        }
                    }
                }
            }
        }
        .frame(minHeight: 60, maxHeight: 300)
    }

    private func projectRow(_ project: ClaudeProject) -> some View {
        HStack(spacing: 8) {
            Button(action: { toggleProject(project.id) }) {
                Image(systemName: expandedProjects.contains(project.id) ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 12)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(expandedProjects.contains(project.id) ? "Collapse project" : "Expand project")

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(project.displayName)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    if project.isStale {
                        Text("stale")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(3)
                    }
                }
                Text("\(project.files.count) \(project.files.count == 1 ? "file" : "files") · \(project.claudeDir)")
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
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                Button("Delete") {
                    monitor.deleteProject(project)
                    confirmDelete = nil
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundColor(.red)
            } else {
                Button(action: { confirmDelete = .project(project.id) }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
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
            ForEach(project.files) { file in
                fileRow(file, projectDisplayName: project.displayName)
            }
        }
        .padding(.leading, 24)
    }

    private func fileRow(_ file: MonitoredFile, projectDisplayName: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: file.isSymlink ? "link" : "doc")
                .font(.caption2)
                .foregroundColor(file.isBrokenSymlink ? .red : .secondary)
                .frame(width: 12)

            VStack(alignment: .leading, spacing: 0) {
                Text(file.name)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if file.isBrokenSymlink {
                    Text("broken symlink")
                        .font(.caption2)
                        .foregroundColor(.red)
                } else if file.isSymlink {
                    Text("→ \((file.resolvedPath as NSString).lastPathComponent)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if !file.isBrokenSymlink {
                Text(formatBytes(file.size))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(sizeColor(file.size))
            }

            if confirmDelete == .file(file.id) {
                Button("Cancel") { confirmDelete = nil }
                    .font(.caption2)
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                Button("Delete") {
                    monitor.deleteFile(file)
                    confirmDelete = nil
                }
                .font(.caption2)
                .buttonStyle(.plain)
                .foregroundColor(.red)
            } else {
                Button(action: { confirmDelete = .file(file.id) }) {
                    Image(systemName: "xmark.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete file")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.subheadline.weight(.medium))
                .padding(.bottom, 2)

            settingRow("Warning threshold", value: $monitor.warningThresholdMB, unit: "MB")
            settingRow("Critical threshold", value: $monitor.criticalThresholdMB, unit: "MB")
            settingRow("Scan interval", value: $monitor.scanIntervalSeconds, unit: "sec")
            settingRow("Stale after", value: $monitor.staleDaysThreshold, unit: "days")

            Toggle("Notifications", isOn: $monitor.notificationsEnabled)
                .font(.subheadline)

            if monitor.notificationsDenied {
                Text("Notifications are denied in System Settings.")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            Toggle("Launch at Login", isOn: $monitor.launchAtLogin)
                .font(.subheadline)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func settingRow(_ label: String, value: Binding<Int>, unit: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            TextField(label, value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                .multilineTextAlignment(.trailing)
            Text(unit)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .leading)
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
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gear")
                    Text(showSettings ? "Hide Settings" : "Settings")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .accessibilityLabel("Settings")
                .keyboardShortcut(",", modifiers: .command)

                Spacer()

                if !monitor.projects.isEmpty {
                    Button(action: { confirmDelete = .all }) {
                        Text("Clean All")
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.orange)
                }

                if confirmDelete == .all {
                    Button("Cancel") { confirmDelete = nil }
                        .font(.caption)
                        .buttonStyle(.plain)
                    Button("Confirm") {
                        monitor.deleteAllProjects()
                        confirmDelete = nil
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                }

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .font(.subheadline)
                .keyboardShortcut("q", modifiers: .command)
            }
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

    private func sizeColor(_ bytes: UInt64) -> Color {
        if bytes >= monitor.criticalBytes { return .red }
        if bytes >= monitor.warningBytes { return .orange }
        return .primary
    }
}
