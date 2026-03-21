import Charts
import SwiftUI

// MARK: - Chart Data Model

private struct ChartBar: Identifiable {
    let id: Date // bucket start
    let projectSizes: [(name: String, size: UInt64)]
    var totalSize: UInt64 { projectSizes.reduce(0) { $0 + $1.size } }
}

// MARK: - Layout Constants

private enum ChartConstants {
    static let chartMinHeight: CGFloat = 150
    static let tooltipWidth: CGFloat = 220
    static let pickerWidth: CGFloat = 240
    static let palette: [Color] = [
        .blue, .green, .orange, .purple, .red, .cyan,
        .pink, .yellow, .indigo, .mint, .teal, .brown
    ]
}

// MARK: - Stats View

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
                .frame(width: ChartConstants.pickerWidth)
            }

            Divider()

            // Summary row
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

            // Chart
            if rangeSnapshots.count < 2 {
                emptyState
            } else if selectedRange == .oneHour {
                areaLineChart(rangeSnapshots)
            } else {
                let bars = aggregateBars(from: rangeSnapshots, range: selectedRange)
                let colorMap = buildColorMap(from: bars)
                // Child view owns hover state so aggregation isn't recomputed on mouse move
                StackedBarChartView(
                    bars: bars,
                    colorMap: colorMap,
                    selectedRange: selectedRange
                )
            }

            // Retention hint for 30d
            if selectedRange == .thirtyDays && historyService.historyRetentionDays < 30 {
                Text("History retention is \(historyService.historyRetentionDays) days. Increase in Settings for full 30-day data.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
    }

    // MARK: - Empty State

    private var emptyState: some View {
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
    }

    // MARK: - Area + Line Chart (1h)

    private func areaLineChart(_ snapshots: [HistorySnapshot]) -> some View {
        Chart(snapshots) { snapshot in
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
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .chartYAxis {
            yAxisMarks
        }
        .frame(minHeight: ChartConstants.chartMinHeight)
    }

    // MARK: - Shared Axis

    private var yAxisMarks: some AxisContent {
        AxisMarks(values: .automatic) { value in
            AxisGridLine()
            AxisTick()
            AxisValueLabel {
                if let bytes = value.as(Double.self), bytes >= 0, bytes <= Double(UInt64.max) {
                    Text(formatBytes(UInt64(bytes)))
                        .font(.caption2)
                }
            }
        }
    }

    // MARK: - Data Aggregation

    /// Groups snapshots into calendar-aligned time buckets for bar chart display.
    /// Uses Calendar-based bucketing (startOfDay / dateInterval) instead of epoch-based bucketing
    /// (as in HistoryService.aggregate) to align bars with human-readable time boundaries.
    private func aggregateBars(from snapshots: [HistorySnapshot], range: TimeRange) -> [ChartBar] {
        guard !snapshots.isEmpty else { return [] }

        let calendar = Calendar.current
        let useHourBuckets = (range == .twentyFourHours)

        // Group snapshots into calendar-aligned buckets
        var buckets: [Date: [HistorySnapshot]] = [:]
        for snapshot in snapshots {
            let bucketStart: Date
            if useHourBuckets {
                bucketStart = calendar.dateInterval(of: .hour, for: snapshot.timestamp)?.start ?? snapshot.timestamp
            } else {
                bucketStart = calendar.startOfDay(for: snapshot.timestamp)
            }
            buckets[bucketStart, default: []].append(snapshot)
        }

        // Convert each bucket to a ChartBar by averaging per-project sizes
        return buckets.keys.sorted().map { bucketDate in
            let group = buckets[bucketDate]!

            // Accumulate per-project sizes and appearance counts
            var projectSums: [String: (total: UInt64, appearances: UInt64)] = [:]
            for snapshot in group {
                for project in snapshot.projects {
                    let existing = projectSums[project.name] ?? (total: 0, appearances: 0)
                    projectSums[project.name] = (total: existing.total + project.size, appearances: existing.appearances + 1)
                }
            }

            // Average each project's size by its own appearance count (consistent with HistoryService.aggregate)
            let projectSizes = projectSums.map { name, sums in
                (name: name, size: sums.total / sums.appearances)
            }.sorted { $0.size > $1.size }

            return ChartBar(id: bucketDate, projectSizes: projectSizes)
        }
    }

    // MARK: - Color Mapping

    private func buildColorMap(from bars: [ChartBar]) -> [String: Color] {
        var allNames: Set<String> = []
        for bar in bars {
            for project in bar.projectSizes {
                allNames.insert(project.name)
            }
        }

        let sorted = allNames.sorted()
        var colorMap: [String: Color] = [:]
        for (index, name) in sorted.enumerated() {
            colorMap[name] = ChartConstants.palette[index % ChartConstants.palette.count]
        }
        return colorMap
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
}

// MARK: - Stacked Bar Chart (child view)

/// Separate view that owns hover state so parent doesn't recompute aggregation on mouse moves.
private struct StackedBarChartView: View {
    let bars: [ChartBar]
    let colorMap: [String: Color]
    let selectedRange: TimeRange

    @State private var hoveredBarDate: Date?
    @State private var hoverLocation: CGPoint = .zero
    @State private var chartWidth: CGFloat = 0

    // Cached formatters to avoid repeated allocation during hover tracking
    private static let tooltipFormatters: [String: DateFormatter] = {
        let formats = ["HH:mm", "HH:00", "EEEE", "MMM d"]
        var map: [String: DateFormatter] = [:]
        for fmt in formats {
            let f = DateFormatter()
            f.dateFormat = fmt
            map[fmt] = f
        }
        return map
    }()

    var body: some View {
        let projectNames = colorMap.keys.sorted()

        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                Chart {
                    ForEach(bars) { bar in
                        ForEach(bar.projectSizes, id: \.name) { project in
                            BarMark(
                                x: .value("Time", bar.id, unit: barCalendarUnit),
                                y: .value("Size", Double(project.size))
                            )
                            .foregroundStyle(by: .value("Project", project.name))
                        }
                    }
                }
                .chartForegroundStyleScale(
                    domain: projectNames,
                    range: projectNames.map { colorMap[$0] ?? .gray }
                )
                .chartLegend(.hidden)
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
                            if let bytes = value.as(Double.self), bytes >= 0, bytes <= Double(UInt64.max) {
                                Text(formatBytes(UInt64(bytes)))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    hoverLocation = location
                                    chartWidth = geometry.size.width
                                    if let date: Date = proxy.value(atX: location.x) {
                                        hoveredBarDate = snapToBarBucket(date: date)
                                    }
                                case .ended:
                                    hoveredBarDate = nil
                                }
                            }
                    }
                }
                .frame(minHeight: ChartConstants.chartMinHeight)

                // Tooltip overlay — positioned to left or right of the hovered bar
                if let hoveredDate = hoveredBarDate,
                   let bar = bars.first(where: { Int($0.id.timeIntervalSince1970) == Int(hoveredDate.timeIntervalSince1970) }) {
                    let tooltipX = tooltipOffsetX(
                        hoverX: hoverLocation.x,
                        tooltipWidth: ChartConstants.tooltipWidth,
                        chartWidth: chartWidth
                    )
                    tooltipView(bar: bar)
                        .offset(x: tooltipX, y: 4)
                        .allowsHitTesting(false)
                }
            }

            // Legend
            legendView
        }
    }

    // MARK: - Tooltip

    private func tooltipView(bar: ChartBar) -> some View {
        let sorted = bar.projectSizes.sorted { $0.size > $1.size }
        let total = bar.totalSize

        return VStack(alignment: .leading, spacing: 4) {
            Text(tooltipDateHeader(bar.id))
                .font(.caption.bold())

            Text("Total: \(formatBytes(total))")
                .font(.caption2)
                .foregroundColor(.secondary)

            if !sorted.isEmpty {
                Divider()
                ForEach(sorted, id: \.name) { project in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(colorMap[project.name] ?? .gray)
                            .frame(width: 8, height: 8)
                        Text(project.name)
                            .font(.caption2)
                            .lineLimit(1)
                        Spacer()
                        Text(formatBytes(project.size))
                            .font(.caption2.monospacedDigit())
                        if total > 0 {
                            Text("(\(percentString(project.size, of: total)))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(.regularMaterial)
        .cornerRadius(6)
        .shadow(radius: 4)
        .frame(width: ChartConstants.tooltipWidth)
    }

    /// Position tooltip to the right of the hovered bar, or flip to the left if near the right edge.
    private func tooltipOffsetX(hoverX: CGFloat, tooltipWidth: CGFloat, chartWidth: CGFloat) -> CGFloat {
        let gap: CGFloat = 12
        let rightX = hoverX + gap
        let leftX = hoverX - tooltipWidth - gap

        // If tooltip fits to the right, place it there; otherwise place it to the left
        if rightX + tooltipWidth <= chartWidth {
            return rightX
        } else {
            return max(0, leftX)
        }
    }

    private func tooltipDateHeader(_ date: Date) -> String {
        let format: String
        switch selectedRange {
        case .oneHour: format = "HH:mm"
        case .twentyFourHours: format = "HH:00"
        case .sevenDays: format = "EEEE"
        case .thirtyDays: format = "MMM d"
        }
        return Self.tooltipFormatters[format]?.string(from: date) ?? ""
    }

    // MARK: - Legend

    private var legendView: some View {
        let sorted = colorMap.keys.sorted()
        return FlowLayout(spacing: 8) {
            ForEach(sorted, id: \.self) { name in
                HStack(spacing: 4) {
                    Circle()
                        .fill(colorMap[name] ?? .gray)
                        .frame(width: 8, height: 8)
                    Text(name)
                        .font(.caption2)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Axis Formatting

    private var xAxisFormat: Date.FormatStyle {
        switch selectedRange {
        case .twentyFourHours:
            return .dateTime.hour().minute()
        case .sevenDays:
            return .dateTime.weekday(.abbreviated)
        case .thirtyDays:
            return .dateTime.month(.abbreviated).day()
        case .oneHour:
            // Unreachable: 1h uses area chart, not bar chart. Included for exhaustive switch.
            return .dateTime.hour().minute()
        }
    }

    private var barCalendarUnit: Calendar.Component {
        switch selectedRange {
        case .twentyFourHours:
            return .hour
        case .sevenDays, .thirtyDays:
            return .day
        case .oneHour:
            // Unreachable: 1h uses area chart, not bar chart. Included for exhaustive switch.
            return .hour
        }
    }

    // MARK: - Bucket Snapping

    private func snapToBarBucket(date: Date) -> Date {
        let calendar = Calendar.current
        switch selectedRange {
        case .twentyFourHours:
            return calendar.dateInterval(of: .hour, for: date)?.start ?? date
        case .sevenDays, .thirtyDays:
            return calendar.startOfDay(for: date)
        case .oneHour:
            // Unreachable: 1h uses area chart, not bar chart. Included for exhaustive switch.
            return calendar.dateInterval(of: .hour, for: date)?.start ?? date
        }
    }

    // MARK: - Helpers

    private func percentString(_ part: UInt64, of total: UInt64) -> String {
        let pct = Double(part) / Double(total) * 100
        if pct < 1 { return "<1%" }
        return String(format: "%.0f%%", pct)
    }
}

// MARK: - Flow Layout

/// Simple wrapping horizontal layout for the project color legend.
private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct ArrangeResult {
        var size: CGSize
        var positions: [CGPoint]
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                // Wrap to next line
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
            totalHeight = currentY + lineHeight
        }

        return ArrangeResult(
            size: CGSize(width: totalWidth, height: totalHeight),
            positions: positions
        )
    }
}
