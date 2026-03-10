import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var monitor: MonitorService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.headline)
                .padding(.bottom, 4)

            settingRow("Warning threshold", value: $monitor.warningThresholdMB, unit: "MB")
            settingRow("Critical threshold", value: $monitor.criticalThresholdMB, unit: "MB")
            settingRow("Scan interval", value: $monitor.scanIntervalSeconds, unit: "sec")
            settingRow("Stale after", value: $monitor.staleDaysThreshold, unit: "days")

            Divider()
                .padding(.vertical, 4)

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
        .padding(20)
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
