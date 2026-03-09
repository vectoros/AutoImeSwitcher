import SwiftUI

@main
struct AutoImeSwitcherApp: App {
    @StateObject private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            SettingsView()
                .environmentObject(appState)
                .frame(minWidth: 640, minHeight: 420)
                .onAppear {
                    appDelegate.attachWindowDelegate()
                    // #region debug-point
                    DebugReporter.send(
                        event: "settings_view_on_appear",
                        data: [
                            "thread": Thread.isMainThread ? "main" : "background"
                        ]
                    )
                    // #endregion debug-point
                }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let windowDelegate = WindowDelegate()
    private let statusMenu = NSMenu()
    private weak var primaryWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "AutoImeSwitcher")
            button.target = self
            button.action = #selector(didClickStatusItem)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        let quitItem = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        statusMenu.addItem(quitItem)
        statusItem = item
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeMain(_:)),
            name: NSWindow.didBecomeMainNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive(_:)),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettingsWindow()
        return true
    }

    func attachWindowDelegate() {
        _ = mainWindow()
        pruneExtraWindows()
    }

    @objc private func didClickStatusItem() {
        guard let event = NSApp.currentEvent else {
            toggleSettingsWindow()
            return
        }
        if event.type == .rightMouseUp {
            showStatusMenu()
            return
        }
        toggleSettingsWindow()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func showStatusMenu() {
        if let button = statusItem?.button {
            statusMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
        }
    }

    private func toggleSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        pruneExtraWindows()
        if let window = mainWindow() {
            if window.isVisible {
                window.orderOut(nil)
            } else {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    private func showSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        pruneExtraWindows()
        if let window = mainWindow() {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func mainWindow() -> NSWindow? {
        if let window = primaryWindow {
            return window
        }
        if let window = NSApp.windows.first(where: { !($0 is NSPanel) }) {
            primaryWindow = window
            window.delegate = windowDelegate
            return window
        }
        return nil
    }

    @objc private func windowDidBecomeMain(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else {
            return
        }
        if window is NSPanel {
            return
        }
        pruneExtraWindows(primary: window)
        if primaryWindow == nil {
            primaryWindow = window
            window.delegate = windowDelegate
            return
        }
        if window != primaryWindow {
            window.orderOut(nil)
            primaryWindow?.makeKeyAndOrderFront(nil)
        }
    }

    @objc func applicationDidBecomeActive(_ notification: Notification) {
        pruneExtraWindows()
    }

    @objc private func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else {
            return
        }
        if window == primaryWindow {
            primaryWindow = nil
        }
    }

    private func pruneExtraWindows(primary: NSWindow? = nil) {
        let windows = NSApp.windows.filter { !($0 is NSPanel) }
        guard let keep = primary ?? primaryWindow ?? windows.first else {
            return
        }
        if primaryWindow == nil {
            primaryWindow = keep
            keep.delegate = windowDelegate
        }
        for window in windows where window != keep {
            window.orderOut(nil)
        }
    }
}

final class WindowDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
