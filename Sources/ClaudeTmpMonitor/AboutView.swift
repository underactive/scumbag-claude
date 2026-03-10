import SwiftUI

struct AboutView: View {
    @EnvironmentObject var updateService: UpdateService
    private static let githubURL = URL(string: "https://github.com/underactive/scumbag-claude")

    var body: some View {
        VStack(spacing: 12) {
            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 64, height: 64)
            }

            Text("Scumbag Claude")
                .font(.title2.weight(.semibold))

            Text("Version \(updateService.currentVersion)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            updateStatusText

            if let url = Self.githubURL {
                Link("GitHub", destination: url)
                    .font(.subheadline)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var updateStatusText: some View {
        switch updateService.status {
        case .available(let version, _, _):
            Text("Update v\(version) available")
                .font(.caption)
                .foregroundColor(.accentColor)
        case .upToDate:
            Text("Up to date")
                .font(.caption)
                .foregroundColor(.green)
        case .checking:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.mini)
                Text("Checking...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        default:
            EmptyView()
        }
    }
}
