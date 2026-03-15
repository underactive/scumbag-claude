import Charts
import SwiftUI

struct StatsView: View {
    @EnvironmentObject var historyService: HistoryService
    @State private var selectedRange: TimeRange = .twentyFourHours

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with time range picker
            HStack {
                Text("Statistics")
                    .font(.headline)
                Spacer()
                Picker("Time Range", selection: $selectedRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            Divider()

            // Summary row — single filter pass, reused for peak/avg
            let rangeSnapshots = historyService.snapshots(for: selectedRange)
            let currentSize = historyService.snapshots.max(by: { $0.timestamp < $1.timestamp })?.totalSize ?? 0
            let peak = historyService.peakSize(in: rangeSnapshots)
            let average = historyService.averageSize(in: rangeSnapshots)

            HStack(spacing: 24) {
                statItem("Current", value: formatBytes(currentSize))
                statItem("Peak", value: formatBytes(peak))
                statItem("Average", value: formatBytes(average))
                Spacer()
            }

            Divider()

            // Chart — Swift Charts requires >= 2 data points to render LineMark/AreaMark
            if rangeSnapshots.count < 2 {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "chart.xyaxis.line")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No historical data yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Statistics will appear after a few scans.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                Chart(rangeSnapshots) { snapshot in
                    AreaMark(
                        x: .value("Time", snapshot.timestamp),
                        y: .value("Size", Double(snapshot.totalSize))
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentColor.opacity(0.3), .accentColor.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Time", snapshot.timestamp),
                        y: .value("Size", Double(snapshot.totalSize))
                    )
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: xAxisFormat)
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let bytes = value.as(Double.self), bytes >= 0 {
                                Text(formatBytes(UInt64(bytes)))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(minHeight: 150)
            }
        }
        .padding(20)
    }

    // MARK: - Helpers

    private func statItem(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium).monospacedDigit())
        }
    }

    private var xAxisFormat: Date.FormatStyle {
        switch selectedRange {
        case .oneHour:
            return .dateTime.hour().minute()
        case .twentyFourHours:
            return .dateTime.hour().minute()
        case .sevenDays:
            return .dateTime.weekday(.abbreviated)
        }
    }
}
