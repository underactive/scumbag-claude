import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct ClaudeTmpMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var monitor = MonitorService()

    // MARK: - Pre-cached menubar icons

    private static let iconSize = NSSize(width: 18, height: 18)

    private static let baseImage: NSImage? = {
        guard let url = Bundle.module.url(forResource: "MenuBarIcon", withExtension: "png"),
              let img = NSImage(contentsOf: url) else { return nil }
        img.size = iconSize
        return img
    }()

    private static let normalImage: NSImage? = {
        guard let img = baseImage?.copy() as? NSImage else { return nil }
        img.isTemplate = true
        return img
    }()

    private static let warningImage: NSImage? = tinted(with: .orange)
    private static let criticalImage: NSImage? = tinted(with: .red)

    // Composites the base icon with a color using .sourceAtop to tint only opaque pixels
    private static func tinted(with color: NSColor) -> NSImage? {
        guard let original = baseImage else { return nil }
        let tinted = NSImage(size: iconSize, flipped: false) { rect in
            original.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        tinted.isTemplate = false
        return tinted
    }

    private static func image(for status: MonitorStatus) -> NSImage? {
        switch status {
        case .normal: return normalImage
        case .warning: return warningImage
        case .critical: return criticalImage
        }
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(monitor)
        } label: {
            HStack(spacing: 4) {
                if let img = Self.image(for: monitor.status) {
                    Image(nsImage: img)
                } else {
                    Image(systemName: monitor.statusIcon)
                }
                if monitor.totalSize > 0 {
                    Text(formatBytes(monitor.totalSize))
                        .font(.caption)
                }
            }
            .accessibilityLabel("Scumbag Claude status")
        }
        .menuBarExtraStyle(.window)
    }
}
