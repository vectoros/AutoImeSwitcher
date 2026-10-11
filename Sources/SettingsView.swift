import AppKit
import SwiftUI

private final class SettingsViewState: ObservableObject {
    @Published var selection = "rules"
    @Published var search = ""
}

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewState = SettingsViewState()

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(alignment: .leading, spacing: 20) {
                header
                if let error = appState.configurationError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout).foregroundColor(.orange).textSelection(.enabled)
                }
                if viewState.selection == "rules" {
                    rules
                } else {
                    LogPanel(logStore: appState.logStore)
                }
                Divider()
                HStack(spacing: 8) {
                    Circle().fill(appState.isEnabled ? Color.green : Color.secondary).frame(width: 7, height: 7)
                    Text(appState.status).font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text("\(appState.mappings.count) 个应用规则").font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 780, minHeight: 560)
        .onAppear { appState.refreshInputSources() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "keyboard.badge.ellipsis")
                    .font(.system(size: 30)).foregroundColor(.accentColor)
                Text("AutoImeSwitcher").font(.headline)
                Text("让输入法跟随你的工作").font(.caption).foregroundColor(.secondary)
            }
            VStack(spacing: 6) {
                navigationItem("应用规则", icon: "square.grid.2x2", id: "rules")
                navigationItem("运行日志", icon: "list.bullet.rectangle", id: "logs")
            }
            Divider()
            Toggle("自动切换", isOn: $appState.isEnabled).toggleStyle(.switch)
                .font(.callout)
            VStack(alignment: .leading, spacing: 6) {
                Text("当前应用").font(.caption).foregroundColor(.secondary)
                Text(appState.frontmostName).font(.callout).lineLimit(2)
                Text("当前输入法").font(.caption).foregroundColor(.secondary).padding(.top, 8)
                Text(appState.currentSourceName).font(.callout).lineLimit(2)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                Label(appState.accessibilityGranted ? "焦点检测已授权" : "基础应用检测",
                      systemImage: appState.accessibilityGranted ? "checkmark.shield" : "shield")
                    .font(.caption).foregroundColor(appState.accessibilityGranted ? .green : .secondary)
                Text(appState.accessibilityGranted
                     ? (appState.windowMonitoring ? "正在监听窗口与输入框变化" : "当前应用使用前台检测")
                     : "授权后可检测同一应用内的窗口和输入框变化。")
                    .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                if !appState.accessibilityGranted {
                    Button("启用增强检测…") { appState.requestAccessibility() }
                        .font(.caption)
                }
            }
        }
        .padding(20)
        .frame(width: 190)
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    private func navigationItem(_ title: String, icon: String, id: String) -> some View {
        Button { viewState.selection = id } label: {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
            }
            .padding(10)
            .background(viewState.selection == id ? Color.accentColor.opacity(0.13) : Color.clear)
            .cornerRadius(8)
            .foregroundColor(viewState.selection == id ? .accentColor : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(viewState.selection == id ? .isSelected : [])
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(viewState.selection == "rules" ? "应用规则" : "运行日志").font(.largeTitle.weight(.semibold))
                Text(viewState.selection == "rules" ? "为每个应用选择合适的输入法。" : "查看最近的焦点检测与切换结果。")
                    .foregroundColor(.secondary)
            }
            Spacer()
            if viewState.selection == "rules" {
                Button(action: pickApplication) { Label("添加应用", systemImage: "plus") }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.availableInputSources.isEmpty || appState.configurationError != nil)
            }
        }
    }

    private var rules: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("搜索应用名称或标识", text: $viewState.search).textFieldStyle(.plain)
                    if !viewState.search.isEmpty {
                        Button { viewState.search = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).accessibilityLabel("清除搜索")
                    }
                }
                .padding(9).background(Color(nsColor: .textBackgroundColor)).cornerRadius(8)
                Button { appState.refreshInputSources() } label: { Image(systemName: "arrow.clockwise") }
                    .help("刷新输入法与检测权限").accessibilityLabel("刷新输入法与检测权限")
            }
            if appState.availableInputSources.isEmpty {
                Label("未发现可用输入法，请在系统设置中添加后刷新。", systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundColor(.orange)
            }
            if filteredMappings.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: viewState.search.isEmpty ? "keyboard" : "magnifyingglass")
                        .font(.system(size: 40, weight: .light)).foregroundColor(.secondary)
                    Text(viewState.search.isEmpty ? "从常用应用开始" : "没有匹配的应用").font(.title3.weight(.medium))
                    Text(viewState.search.isEmpty ? "添加应用并指定输入法，切换焦点时自动生效。" : "试试其他名称或应用标识。")
                        .font(.callout).foregroundColor(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredMappings, id: \.bundleId) { mapping in
                            MappingRow(mapping: mapping, availableInputSources: appState.availableInputSources,
                                       onChange: { appState.setMapping(bundleId: mapping.bundleId, inputSourceId: $0) },
                                       onRemove: { appState.removeMapping(bundleId: mapping.bundleId) })
                        }
                    }
                    .padding(2)
                }
            }
            Text("未配置的应用会保留当前输入法。暂停时可自由手动切换。")
                .font(.caption).foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
    }

    private var filteredMappings: [AppMapping] {
        appState.mappings.map { AppMapping(bundleId: $0.key, inputSourceId: $0.value) }
            .filter { viewState.search.isEmpty || $0.displayName.localizedCaseInsensitiveContains(viewState.search) || $0.bundleId.localizedCaseInsensitiveContains(viewState.search) }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    private func pickApplication() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.prompt = "添加应用"
        panel.begin { response in
            guard response == .OK else { return }
            let source = InputSourceManager.resolveInputSourceId("ABC", in: appState.availableInputSources)
                ?? appState.availableInputSources.first?.id
            guard let source = source else { return }
            for url in panel.urls {
                guard let bundleId = Bundle(url: url)?.bundleIdentifier,
                      appState.mappings[bundleId] == nil else { continue }
                appState.setMapping(bundleId: bundleId, inputSourceId: source)
            }
        }
    }
}

struct MappingRow: View {
    let mapping: AppMapping
    let availableInputSources: [InputSource]
    let onChange: (String) -> Void
    let onRemove: () -> Void

    private var unavailable: Bool { !availableInputSources.contains { $0.id == mapping.inputSourceId } }

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: mapping.icon).resizable().frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(mapping.displayName).font(.headline).lineLimit(1)
                Text(mapping.bundleId).font(.caption).foregroundColor(.secondary).lineLimit(1).truncationMode(.middle)
                if unavailable {
                    Label("输入法暂不可用，规则已保留", systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundColor(.orange)
                }
            }
            Spacer(minLength: 4)
            Picker("输入法", selection: Binding(get: { mapping.inputSourceId }, set: onChange)) {
                if unavailable { Text("暂不可用").tag(mapping.inputSourceId) }
                ForEach(availableInputSources) { source in Text(source.displayName).tag(source.id) }
            }
            .labelsHidden().frame(width: 155)
            .accessibilityLabel("\(mapping.displayName) 的输入法")
            Button(action: onRemove) { Image(systemName: "minus.circle").foregroundColor(.secondary) }
                .buttonStyle(.borderless).help("移除规则").accessibilityLabel("移除 \(mapping.displayName) 的规则")
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.06)))
    }
}

private struct LogPanel: View {
    @ObservedObject var logStore: LogStore

    private var text: String { logStore.entries.map { "\($0.time)  \($0.event)  \($0.data)" }.joined(separator: "\n") }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("仅在内存保留最近 300 条，不记录输入内容。")
                    .font(.caption).foregroundColor(.secondary)
                Spacer()
                Button("复制") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }.disabled(logStore.entries.isEmpty)
                Button("清空") { logStore.clear() }.disabled(logStore.entries.isEmpty)
            }
            ScrollView {
                Text(logStore.entries.isEmpty ? "暂无日志，切换到已配置的应用后查看。" : text)
                    .font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading).padding(14)
            }
            .background(Color(nsColor: .textBackgroundColor)).cornerRadius(10)
        }
        .frame(maxHeight: .infinity)
    }
}

struct AppMapping {
    let bundleId: String
    let inputSourceId: String

    private var url: URL? { NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) }
    var displayName: String {
        guard let url = url else { return bundleId }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
    var icon: NSImage {
        url.map { NSWorkspace.shared.icon(forFile: $0.path) }
            ?? NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil)!
    }
}
