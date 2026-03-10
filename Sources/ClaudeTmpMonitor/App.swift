import SwiftUI
import AppKit
import Combine

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var rightClickMenu: NSMenu!
    let monitor = MonitorService()
    private var cancellables = Set<AnyCancellable>()
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?

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
        let img: NSImage?
        switch status {
        case .normal: img = normalImage
        case .warning: img = warningImage
        case .critical: img = criticalImage
        }
        // Fallback to SF Symbol if resource image is missing
        if let img { return img }
        let fallback = NSImage(systemSymbolName: "externaldrive", accessibilityDescription: "Scumbag Claude")
        fallback?.size = iconSize
        fallback?.isTemplate = (status == .normal)
        return fallback
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = Self.image(for: .normal)
            button.imagePosition = .imageLeading
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.action = #selector(statusItemClicked(_:))
            button.target = self
        }

        // Popover
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 380, height: 400)
        popover.contentViewController = NSHostingController(
            rootView: ContentView(onOpenSettings: { [weak self] in self?.openSettings() })
                .environmentObject(monitor)
        )

        // Right-click menu
        rightClickMenu = NSMenu()
        rightClickMenu.addItem(
            withTitle: "About Scumbag Claude",
            action: #selector(showAbout),
            keyEquivalent: ""
        ).target = self
        rightClickMenu.addItem(.separator())
        rightClickMenu.addItem(
            withTitle: "Quit",
            action: #selector(quitApp),
            keyEquivalent: "q"
        ).target = self

        // Reactive icon/title updates
        monitor.$status.combineLatest(monitor.$totalSize)
            .sink { [weak self] status, totalSize in
                self?.updateStatusItemAppearance(status: status, totalSize: totalSize)
            }
            .store(in: &cancellables)
    }

    // MARK: - Status Item Actions

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Set menu, click to show it, then clear so left-click doesn't show menu
            statusItem.menu = rightClickMenu
            sender.performClick(nil)
            statusItem.menu = nil
        } else {
            togglePopover(sender)
        }
    }

    private func togglePopover(_ sender: NSView) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func updateStatusItemAppearance(status: MonitorStatus, totalSize: UInt64) {
        guard let button = statusItem.button else { return }
        button.image = Self.image(for: status)
        if totalSize > 0 {
            button.title = " \(formatBytes(totalSize))"
        } else {
            button.title = ""
        }
    }

    // MARK: - Settings Window

    func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
            .environmentObject(monitor)
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 350, height: 300))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }

    // MARK: - About Window

    @objc func showAbout() {
        if let window = aboutWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let aboutView = AboutView()
        let hostingController = NSHostingController(rootView: aboutView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "About Scumbag Claude"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 300, height: 220))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        aboutWindow = window
    }

    // MARK: - Quit

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

@main
struct ClaudeTmpMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
