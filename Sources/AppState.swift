import AppKit
import Carbon
import Combine

final class AppState: ObservableObject {
    @Published private(set) var mappings: [String: String] = [:]
    @Published private(set) var availableInputSources: [InputSource] = []
    @Published var isEnabled = true {
        didSet {
            coordinator.cancel()
            status = isEnabled ? "等待焦点变化" : "自动切换已暂停"
            if isEnabled { monitor.refresh() }
        }
    }
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var windowMonitoring = false
    @Published private(set) var frontmostName = "等待检测"
    @Published private(set) var currentSourceName = "未知"
    @Published private(set) var status = "等待焦点变化"
    @Published private(set) var configurationError: String?
    let logStore = LogStore.shared

    private let monitor = FocusMonitor()
    private var inputObservers: [NSObjectProtocol] = []
    private var savedConfig = ConfigFile(entries: [])
    private var canSave = true
    private lazy var coordinator = SwitchCoordinator(
        isCurrent: { [weak self] pid, source in
            guard let self = self, self.isEnabled,
                  let app = NSWorkspace.shared.frontmostApplication,
                  app.processIdentifier == pid, let bundleId = app.bundleIdentifier else { return false }
            return self.mappings[bundleId] == source
        },
        currentSource: { InputSourceManager.currentInputSource()?.id },
        select: { InputSourceManager.selectInputSource(id: $0) },
        report: { [weak self] success, detail in
            guard let self = self else { return }
            self.updateCurrentSource()
            self.status = success ? "已匹配应用输入法" : "切换失败，请检查输入法是否可用"
            self.logStore.record(success ? "切换成功" : "切换失败", detail)
        }
    )

    init() {
        availableInputSources = InputSourceManager.listKeyboardInputSources()
        loadMappings()
        monitor.onPermission = { [weak self] granted, observing in
            self?.accessibilityGranted = granted
            self?.windowMonitoring = observing
        }
        monitor.onFocus = { [weak self] app, reason in self?.handleFocus(app, reason: reason) }
        let center = DistributedNotificationCenter.default()
        inputObservers.append(center.addObserver(
            forName: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil, queue: .main
        ) { [weak self] _ in self?.updateCurrentSource() })
        inputObservers.append(center.addObserver(
            forName: Notification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String),
            object: nil, queue: .main
        ) { [weak self] _ in self?.refreshInputSources() })
        monitor.refresh()
        updateCurrentSource()
    }

    deinit {
        inputObservers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
    }

    func requestAccessibility() { monitor.requestPermission() }

    func setMapping(bundleId: String, inputSourceId: String) {
        guard canSave else { return }
        mappings[bundleId] = inputSourceId
        saveMappings()
        monitor.refresh()
    }

    func removeMapping(bundleId: String) {
        guard canSave else { return }
        mappings.removeValue(forKey: bundleId)
        saveMappings()
        monitor.refresh()
    }

    func refreshInputSources() {
        availableInputSources = InputSourceManager.listKeyboardInputSources()
        mappings = mappings.mapValues { InputSourceManager.resolveInputSourceId($0, in: availableInputSources) ?? $0 }
        updateCurrentSource()
        monitor.refresh()
    }

    private func handleFocus(_ app: NSRunningApplication?, reason: String) {
        coordinator.cancel()
        frontmostName = app?.localizedName ?? "无前台应用"
        updateCurrentSource()
        guard isEnabled else { return }
        guard let app = app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            status = "等待切换到其他应用"
            return
        }
        guard let bundleId = app.bundleIdentifier, let source = mappings[bundleId] else {
            status = "此应用无规则，保留当前输入法"
            return
        }
        guard availableInputSources.contains(where: { $0.id == source }) else {
            status = "规则中的输入法暂不可用"
            return
        }
        status = "正在匹配输入法…"
        logStore.record(reason, bundleId)
        coordinator.request(pid: app.processIdentifier, source: source)
    }

    private func updateCurrentSource() {
        currentSourceName = InputSourceManager.currentInputSource()?.name ?? "未知"
    }

    private var configURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AutoImeSwitcher/config.json")
    }

    private func loadMappings() {
        guard FileManager.default.fileExists(atPath: configURL.path) else { return }
        do {
            savedConfig = try JSONDecoder().decode(ConfigFile.self, from: Data(contentsOf: configURL))
            mappings = savedConfig.mappings(availableSources: availableInputSources)
        } catch {
            canSave = false
            configurationError = "无法读取配置，已保留原文件。请检查 \(configURL.path)，修复后重新启动。"
            logStore.record("读取配置失败", error.localizedDescription)
        }
    }

    private func saveMappings() {
        guard canSave else { return }
        let config = ConfigFile.updated(mappings: mappings, sources: availableInputSources, previous: savedConfig)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: configURL, options: .atomic)
            savedConfig = config
            configurationError = nil
        } catch {
            configurationError = "配置保存失败：\(error.localizedDescription)"
            logStore.record("保存配置失败", error.localizedDescription)
        }
    }
}

final class LogStore: ObservableObject {
    static let shared = LogStore()
    @Published private(set) var entries: [LogEntry] = []

    func record(_ event: String, _ detail: String) {
        precondition(Thread.isMainThread)
        entries.append(LogEntry(time: Date().formatted(date: .omitted, time: .standard), event: event, data: detail))
        if entries.count > 300 { entries.removeFirst(entries.count - 300) }
    }

    func clear() { entries.removeAll() }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let time: String
    let event: String
    let data: String
}
