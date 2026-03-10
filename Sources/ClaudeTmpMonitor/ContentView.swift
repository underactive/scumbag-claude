import SwiftUI

// MARK: - Delete Confirmation

enum DeleteConfirmation: Equatable {
    case file(String)
    case project(String)
    case all
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

// MARK: - Main Content View

struct ContentView: View {
    @EnvironmentObject var monitor: MonitorService
    @State private var expandedProjects: Set<String> = []
    @State private var confirmDelete: DeleteConfirmation? = nil
    var onOpenSettings: () -> Void = {}

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
            footerSection
        }
        .frame(width: 380)
        .onAppear { confirmDelete = nil }
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
            .buttonStyle(HoverButtonStyle())
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
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                Button("Delete") {
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
            ForEach(project.files) { file in
                fileRow(file)
            }
        }
        .padding(.leading, 24)
    }

    private func fileRow(_ file: MonitoredFile) -> some View {
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
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                Button("Delete") {
                    monitor.deleteFile(file)
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

                Spacer()

                if !monitor.projects.isEmpty {
                    Button(action: { confirmDelete = .all }) {
                        Text("Clean All")
                            .font(.subheadline)
                    }
                    .tint(.orange)
                }

                if confirmDelete == .all {
                    Button("Cancel") { confirmDelete = nil }
                        .font(.caption)
                    Button("Confirm") {
                        monitor.deleteAllProjects()
                        confirmDelete = nil
                    }
                    .font(.caption)
                    .tint(.red)
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

    private func sizeColor(_ bytes: UInt64) -> Color {
        if bytes >= monitor.criticalBytes { return .red }
        if bytes >= monitor.warningBytes { return .orange }
        return .primary
    }
}
