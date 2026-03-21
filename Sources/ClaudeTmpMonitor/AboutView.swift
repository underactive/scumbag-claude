import SwiftUI

struct AboutView: View {
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

            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let url = Self.githubURL {
                Link("GitHub", destination: url)
                    .font(.subheadline)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}
