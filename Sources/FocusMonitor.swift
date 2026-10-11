import AppKit
import ApplicationServices

/// Workspace notifications plus optional accessibility focus events. No keystrokes or text are read.
final class FocusMonitor {
    var onFocus: ((NSRunningApplication?, String) -> Void)?
    var onPermission: ((Bool, Bool) -> Void)?
    private var observers: [NSObjectProtocol] = []
    private var timer: Timer?
    private var axObserver: AXObserver?
    private var observedApp: AXUIElement?
    private var lastPID: pid_t?
    private var trusted = false
    private var suspended = false
    private var lastElement: AXUIElement?
    private var lastWindow: AXUIElement?
    private var ticks = 0

    init() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification,
                     NSWorkspace.activeSpaceDidChangeNotification,
                     NSWorkspace.didWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.suspended = false
                self?.refresh(force: true, reason: "应用 / 空间切换")
            })
        }
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.suspended = true
                self?.detachAccessibility()
                self?.lastPID = nil
                self?.onFocus?(nil, "会话暂停")
            })
        }
        let timer = Timer(timeInterval: 0.6, repeats: true) { [weak self] _ in
            guard let self = self, !self.suspended else { return }
            self.ticks += 1
            self.refresh(force: false, reason: "前台校验")
        }
        timer.tolerance = 0.15
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func refresh(force: Bool = true, reason: String = "重新检测") {
        guard !suspended else { return }
        let permission = AXIsProcessTrusted()
        let app = NSWorkspace.shared.frontmostApplication
        let pid = app?.processIdentifier
        let changed = pid != lastPID || permission != trusted
        trusted = permission
        if changed || (trusted && axObserver == nil && ticks % 5 == 0) {
            lastPID = pid
            attachAccessibility(to: app)
        }
        if changed || force { onFocus?(app, reason) }
    }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refresh()
    }

    private func attachAccessibility(to app: NSRunningApplication?) {
        detachAccessibility()
        guard trusted, let app = app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            onPermission?(trusted, false)
            return
        }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.15)
        var observer: AXObserver?
        let result = AXObserverCreate(app.processIdentifier, { _, element, notification, context in
            guard let context = context else { return }
            let monitor = Unmanaged<FocusMonitor>.fromOpaque(context).takeUnretainedValue()
            monitor.focusChanged(element: element, notification: notification as String)
        }, &observer)
        guard result == .success, let observer = observer else {
            onPermission?(trusted, false)
            return
        }
        let context = Unmanaged.passUnretained(self).toOpaque()
        var supported = false
        for name in [kAXFocusedWindowChangedNotification, kAXFocusedUIElementChangedNotification] {
            let result = AXObserverAddNotification(observer, element, name as CFString, context)
            supported = supported || result == .success
        }
        guard supported else {
            onPermission?(trusted, false)
            return
        }
        axObserver = observer
        observedApp = element
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        onPermission?(trusted, true)
    }

    private func focusChanged(element: AXUIElement, notification: String) {
        guard !suspended, let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier == lastPID, let observedApp = observedApp else { return }
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success, pid == app.processIdentifier else { return }
        let isWindow = notification == kAXFocusedWindowChangedNotification
        var value: CFTypeRef?
        let attribute = isWindow ? kAXFocusedWindowAttribute : kAXFocusedUIElementAttribute
        guard AXUIElementCopyAttributeValue(observedApp, attribute as CFString, &value) == .success,
              let value = value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return }
        let focused = unsafeBitCast(value, to: AXUIElement.self)
        AXUIElementSetMessagingTimeout(focused, 0.15)
        if isWindow {
            guard lastWindow.map({ !CFEqual($0, focused) }) ?? true else { return }
            lastWindow = focused
            lastElement = nil
        } else {
            var role: CFTypeRef?
            guard AXUIElementCopyAttributeValue(focused, kAXRoleAttribute as CFString, &role) == .success,
                  let role = role as? String,
                  [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role) else {
                lastElement = nil
                return
            }
            guard lastElement.map({ !CFEqual($0, focused) }) ?? true else { return }
            lastElement = focused
        }
        onFocus?(app, isWindow ? "窗口焦点变化" : "输入框焦点变化")
    }

    private func detachAccessibility() {
        if let observer = axObserver {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        axObserver = nil
        observedApp = nil
        lastElement = nil
        lastWindow = nil
    }

    deinit {
        timer?.invalidate()
        detachAccessibility()
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }
}
