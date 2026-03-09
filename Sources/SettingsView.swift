import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var logStore = LogStore.shared
    @State private var isPickingApp = false
    @State private var showLogs = false

    var body: some View {
        VStack(spacing: 12) {
            header
            content
            footer
            logPanel
        }
        .padding(16)
        .onAppear {
            appState.refreshInputSources()
        }
    }

    private var header: some View {
        HStack {
            Text("应用默认输入法")
                .font(.title2)
            Spacer()
            Button("刷新输入法列表") {
                appState.refreshInputSources()
            }
        }
    }

    private var content: some View {
        List {
            if appState.mappings.isEmpty {
                Text("尚未配置任何应用，未配置应用将使用系统默认输入法。")
            } else {
                ForEach(sortedMappings, id: \.bundleId) { mapping in
                    MappingRow(
                        mapping: mapping,
                        availableInputSources: appState.availableInputSources,
                        onChange: { newSourceId in
                            appState.setMapping(bundleId: mapping.bundleId, inputSourceId: newSourceId)
                        },
                        onRemove: {
                            appState.removeMapping(bundleId: mapping.bundleId)
                        }
                    )
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("添加应用") {
                pickApplication()
            }
            Spacer()
            Toggle("显示日志", isOn: $showLogs)
                .toggleStyle(.switch)
            Spacer()
            Text("前台应用切换时自动匹配对应输入法")
                .foregroundColor(.secondary)
        }
    }

    private var logPanel: some View {
        Group {
            if showLogs {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("运行日志")
                            .font(.headline)
                        Spacer()
                        Button("复制") {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(logText, forType: .string)
                        }
                        Button("清空") {
                            logStore.clear()
                        }
                    }
                    ScrollView {
                        Text(logText)
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 140)
                    .background(Color.black.opacity(0.04))
                    .cornerRadius(6)
                }
            }
        }
    }

    private var logText: String {
        logStore.entries
            .map { "\($0.time)  \($0.event)  \($0.data)" }
            .joined(separator: "\n")
    }

    private var sortedMappings: [AppMapping] {
        appState.mappings.compactMap { bundleId, inputSourceId in
            AppMapping(bundleId: bundleId, inputSourceId: inputSourceId)
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private func pickApplication() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                return
            }
            guard let bundle = Bundle(url: url),
                  let bundleId = bundle.bundleIdentifier
            else {
                return
            }
            let preferredInputSourceId = InputSourceManager.resolveInputSourceId("ABC", in: appState.availableInputSources)
            let fallbackInputSourceId = preferredInputSourceId ?? appState.availableInputSources.first?.id ?? ""
            if !fallbackInputSourceId.isEmpty {
                appState.setMapping(bundleId: bundleId, inputSourceId: fallbackInputSourceId)
            }
        }
    }
}

struct MappingRow: View {
    let mapping: AppMapping
    let availableInputSources: [InputSource]
    let onChange: (String) -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if let icon = mapping.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 28, height: 28)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 28, height: 28)
            }
            VStack(alignment: .leading) {
                Text(mapping.displayName)
                    .font(.headline)
                Text(mapping.bundleId)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Picker("", selection: Binding(
                get: { mapping.inputSourceId },
                set: { onChange($0) }
            )) {
                ForEach(availableInputSources) { source in
                    Text(source.displayName)
                        .tag(source.id)
                }
            }
            .frame(width: 240)
            Button("移除") {
                onRemove()
            }
        }
        .padding(.vertical, 4)
    }
}

struct AppMapping: Hashable {
    let bundleId: String
    let inputSourceId: String

    var displayName: String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
           let bundle = Bundle(url: url),
           let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
            return name
        }
        return bundleId
    }

    var icon: NSImage? {
        NSWorkspace.shared.icon(forFile: (NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)?.path) ?? "")
    }
}
