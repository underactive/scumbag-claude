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

    private var menuBarImage: NSImage? {
        guard let url = Bundle.module.url(forResource: "MenuBarIcon", withExtension: "png"),
              let img = NSImage(contentsOf: url) else { return nil }
        img.size = NSSize(width: 18, height: 18)
        img.isTemplate = true
        return img
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(monitor)
        } label: {
            HStack(spacing: 4) {
                if let img = menuBarImage {
                    Image(nsImage: img)
                } else {
                    Image(systemName: monitor.statusIcon)
                }
                if monitor.totalSize > 0 {
                    Text(formatBytes(monitor.totalSize))
                        .font(.caption)
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
