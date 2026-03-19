import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var monitor: MonitorService
    @EnvironmentObject var updateService: UpdateService
    @EnvironmentObject var historyService: HistoryService
    @EnvironmentObject var watchdogService: WatchdogService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.headline)
                .padding(.bottom, 4)

            settingRow("Warning threshold", value: $monitor.warningThresholdMB, unit: "MB")
            settingRow("Critical threshold", value: $monitor.criticalThresholdMB, unit: "MB")
            settingRow("Scan interval", value: $monitor.scanIntervalSeconds, unit: "sec")
            settingRow("Stale after", value: $monitor.staleDaysThreshold, unit: "days")
            settingRow("History retention", value: $historyService.historyRetentionDays, unit: "days")

            Divider()
                .padding(.vertical, 4)

            Toggle("Show size in menu bar", isOn: $monitor.showSizeInMenuBar)
                .font(.subheadline)

            Toggle("Notifications", isOn: $monitor.notificationsEnabled)
                .font(.subheadline)

            if monitor.notificationsDenied {
                Text("Notifications are denied in System Settings.")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            Toggle("Launch at Login", isOn: $monitor.launchAtLogin)
                .font(.subheadline)

            Toggle("Check for updates automatically", isOn: $updateService.checkForUpdatesAutomatically)
                .font(.subheadline)

            Divider()
                .padding(.vertical, 4)

            watchdogSection
        }
        .padding(20)
    }

    // MARK: - Watchdog Section

    private var watchdogSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("File Write Watchdog", isOn: $watchdogService.isEnabled)
                .font(.subheadline)

            if watchdogService.isEnabled {
                Text("Allowed directories:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                VStack(spacing: 0) {
                    ForEach(Array(watchdogService.allowedDirectories.enumerated()), id: \.offset) { index, dir in
                        HStack {
                            Text(dir)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button(action: { watchdogService.removeDirectory(at: index) }) {
                                Image(systemName: "minus.circle")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        if index < watchdogService.allowedDirectories.count - 1 {
                            Divider()
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )

                Button(action: addDirectoryViaPanel) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add Directory")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                blockedCommandsSection

                HStack(spacing: 4) {
                    Circle()
                        .fill(watchdogService.hookInstalled ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    Text(watchdogService.hookInstalled ? "Hook installed" : "Hook not found")
                        .font(.caption)
                        .foregroundColor(watchdogService.hookInstalled ? .green : .red)
                }

                if let error = watchdogService.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
            }
        }
    }

    // MARK: - Blocked Commands Section

    @State private var newBlockedCommand: String = ""

    private var blockedCommandsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Blocked commands:")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(watchdogService.blockedCommands.enumerated()), id: \.offset) {
                    index, cmd in
                    HStack {
                        Text(cmd)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                        Spacer()
                        Button(action: { watchdogService.removeBlockedCommand(at: index) }) {
                            Image(systemName: "minus.circle")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    if index < watchdogService.blockedCommands.count - 1 {
                        Divider()
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )

            HStack(spacing: 4) {
                TextField("Command name", text: $newBlockedCommand)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: 150)
                    .onSubmit { addBlockedCommandFromField() }
                Button(action: addBlockedCommandFromField) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(newBlockedCommand.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func addBlockedCommandFromField() {
        watchdogService.addBlockedCommand(newBlockedCommand)
        newBlockedCommand = ""
    }

    // MARK: - Helpers

    private func addDirectoryViaPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a directory to allow Claude Code to write to"
        panel.prompt = "Add"

        if panel.runModal() == .OK, let url = panel.url {
            watchdogService.addDirectory(url.path)
        }
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
}
