import AppKit
import Combine
import Foundation

final class AppState: ObservableObject {
    @Published var mappings: [String: String] = [:]
    @Published var availableInputSources: [InputSource] = []
    let logStore = LogStore.shared

    private var observers: [NSObjectProtocol] = []
    private var cancellables = Set<AnyCancellable>()
    private var debugFrontmostTimer: Timer?
    private var debugFrontmostProbeCount = 0

    init() {
        // #region debug-point
        DebugReporter.send(
            event: "appstate_init_start",
            data: [
                "thread": Thread.isMainThread ? "main" : "background"
            ]
        )
        // #endregion debug-point
        availableInputSources = InputSourceManager.listKeyboardInputSources()
        // #region debug-point
        DebugReporter.send(
            event: "appstate_input_sources_loaded",
            data: [
                "count": availableInputSources.count
            ]
        )
        // #endregion debug-point
        loadMappings()
        setupObservers()
        startDebugFrontmostProbe()
        // #region debug-point
        DebugReporter.send(
            event: "appstate_init_end",
            data: [
                "mappings": mappings.count
            ]
        )
        // #endregion debug-point
        $mappings
            .dropFirst()
            .sink { [weak self] value in
                self?.saveMappings(value)
            }
            .store(in: &cancellables)
    }

    deinit {
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    func setMapping(bundleId: String, inputSourceId: String) {
        mappings[bundleId] = inputSourceId
    }

    func removeMapping(bundleId: String) {
        mappings.removeValue(forKey: bundleId)
    }

    func refreshInputSources() {
        availableInputSources = InputSourceManager.listKeyboardInputSources()
        normalizeMappings()
        saveMappings(mappings)
        // #region debug-point
        DebugReporter.send(
            event: "refresh_input_sources",
            data: [
                "count": availableInputSources.count,
                "mappings": mappings.count
            ]
        )
        // #endregion debug-point
    }

    private func setupObservers() {
        // #region debug-point
        DebugReporter.send(event: "setup_observers_start", data: [:])
        // #endregion debug-point
        let observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // #region debug-point
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundleId = app?.bundleIdentifier ?? ""
            let mapped = self?.mappings[bundleId]
            if let current = InputSourceManager.currentInputSource() {
                DebugReporter.send(
                    event: "current_input_source",
                    data: [
                        "phase": "before",
                        "id": current.id,
                        "name": current.name
                    ]
                )
            }
            DebugReporter.send(
                event: "did_activate_application",
                data: [
                    "bundleId": bundleId,
                    "mapped": mapped == nil ? "false" : "true",
                    "inputSourceId": mapped ?? ""
                ]
            )
            // #endregion debug-point
            guard let bundleId = app?.bundleIdentifier,
                  let inputSourceId = mapped
            else {
                return
            }
            // #region debug-point
            DebugReporter.send(
                event: "select_input_source_attempt",
                data: [
                    "bundleId": bundleId,
                    "inputSourceId": inputSourceId
                ]
            )
            // #endregion debug-point
            InputSourceManager.selectInputSource(id: inputSourceId)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let current = InputSourceManager.currentInputSource() {
                    DebugReporter.send(
                        event: "current_input_source",
                        data: [
                            "phase": "after",
                            "id": current.id,
                            "name": current.name
                        ]
                    )
                }
            }
        }
        observers.append(observer)
        let deactivateObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            // #region debug-point
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            DebugReporter.send(
                event: "did_deactivate_application",
                data: [
                    "bundleId": app?.bundleIdentifier ?? ""
                ]
            )
            // #endregion debug-point
        }
        observers.append(deactivateObserver)
        // #region debug-point
        DebugReporter.send(event: "setup_observers_end", data: [:])
        // #endregion debug-point
    }

    private func startDebugFrontmostProbe() {
        debugFrontmostTimer?.invalidate()
        debugFrontmostProbeCount = 0
        debugFrontmostTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            self.debugFrontmostProbeCount += 1
            let frontmost = NSWorkspace.shared.frontmostApplication
            DebugReporter.send(
                event: "frontmost_probe",
                data: [
                    "bundleId": frontmost?.bundleIdentifier ?? "",
                    "name": frontmost?.localizedName ?? "",
                    "appActive": NSApp.isActive ? "true" : "false"
                ]
            )
            if self.debugFrontmostProbeCount >= 30 {
                timer.invalidate()
                self.debugFrontmostTimer = nil
            }
        }
    }

    private func loadMappings() {
        // #region debug-point
        DebugReporter.send(event: "load_mappings_start", data: [:])
        // #endregion debug-point
        let url = configFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            let defaults = defaultEntries()
            mappings = resolveMappings(from: defaults)
            saveConfigFile(entries: defaults)
            // #region debug-point
            DebugReporter.send(
                event: "load_mappings_default_written",
                data: [
                    "entries": defaults.count
                ]
            )
            // #endregion debug-point
            return
        }
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(ConfigFile.self, from: data)
        else {
            mappings = [:]
            // #region debug-point
            DebugReporter.send(event: "load_mappings_decode_failed", data: [:])
            // #endregion debug-point
            return
        }
        mappings = resolveMappings(from: decoded.entries)
        // #region debug-point
        DebugReporter.send(
            event: "load_mappings_success",
            data: [
                "entries": decoded.entries.count,
                "mappings": mappings.count
            ]
        )
        // #endregion debug-point
    }

    private func saveMappings(_ value: [String: String]) {
        let entries = value.map { bundleId, inputSourceId in
            ConfigEntry(
                bundleId: bundleId,
                inputSourceId: inputSourceId,
                inputSourceName: InputSourceManager.displayName(for: inputSourceId, in: availableInputSources)
            )
        }
        saveConfigFile(entries: entries.sorted { $0.bundleId < $1.bundleId })
    }

    private func saveConfigFile(entries: [ConfigEntry]) {
        let file = ConfigFile(entries: entries)
        guard let data = try? JSONEncoder().encode(file) else {
            return
        }
        let url = configFileURL()
        do {
            try ensureConfigDirectory()
            try data.write(to: url, options: .atomic)
        } catch {
            return
        }
    }

    private func resolveMappings(from entries: [ConfigEntry]) -> [String: String] {
        var result: [String: String] = [:]
        for entry in entries {
            guard !entry.bundleId.isEmpty else {
                continue
            }
            if let id = entry.inputSourceId,
               let resolved = InputSourceManager.resolveInputSourceId(id, in: availableInputSources) {
                result[entry.bundleId] = resolved
                continue
            }
            if let name = entry.inputSourceName,
               let resolved = InputSourceManager.resolveInputSourceId(name, in: availableInputSources) {
                result[entry.bundleId] = resolved
            }
        }
        return result
    }

    private func normalizeMappings() {
        mappings = mappings.compactMapValues { id in
            InputSourceManager.resolveInputSourceId(id, in: availableInputSources)
        }
    }

    private func configFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("AutoImeSwitcher", isDirectory: true)
        return dir.appendingPathComponent("config.json")
    }

    private func ensureConfigDirectory() throws {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("AutoImeSwitcher", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private func defaultEntries() -> [ConfigEntry] {
        []
    }
}

private struct ConfigFile: Codable {
    let entries: [ConfigEntry]
}

private struct ConfigEntry: Codable, Hashable {
    let bundleId: String
    let inputSourceId: String?
    let inputSourceName: String?
}

struct DebugReporter {
    static let sessionId = "autoime-20260223-001"
    static let runId = "pre-fix"
    static let endpoint = URL(string: "http://127.0.0.1:7777/event")!
    private static let formatter = ISO8601DateFormatter()

    static func send(event: String, data: [String: Any]) {
        let time = formatter.string(from: Date())
        var payload: [String: Any] = [
            "sessionId": sessionId,
            "runId": runId,
            "event": event,
            "data": data,
            "ts": time
        ]
        if let bundleId = Bundle.main.bundleIdentifier {
            payload["bundleId"] = bundleId
        }
        let dataString = data
            .map { "\($0.key)=\($0.value)" }
            .sorted()
            .joined(separator: " ")
        LogStore.shared.append(
            LogEntry(time: time, event: event, data: dataString)
        )
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        guard let body = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            return
        }
        URLSession.shared.uploadTask(with: request, from: body).resume()
    }
}

final class LogStore: ObservableObject {
    static let shared = LogStore()
    @Published private(set) var entries: [LogEntry] = []

    func append(_ entry: LogEntry) {
        entries.append(entry)
        if entries.count > 500 {
            entries.removeFirst(entries.count - 500)
        }
    }

    func clear() {
        entries.removeAll()
    }
}

struct LogEntry: Identifiable, Hashable {
    let id = UUID()
    let time: String
    let event: String
    let data: String
}
