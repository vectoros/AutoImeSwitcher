import Carbon
import Foundation

struct InputSource: Identifiable, Hashable {
    let id: String
    let name: String

    var displayName: String {
        name
    }
}

enum InputSourceManager {
    private static let builtinAliases: [String: [String]] = [
        "ABC": ["com.apple.keylayout.ABC"],
        "拼音": ["com.apple.inputmethod.SCIM.ITABC"]
    ]

    static func listKeyboardInputSources() -> [InputSource] {
        let inputMethodCategory: CFString = "TISCategoryInputMethod" as CFString
        let categories: [CFString] = [
            kTISCategoryKeyboardInputSource,
            inputMethodCategory
        ]
        var sourcesById: [String: InputSource] = [:]
        for category in categories {
            let filter: [String: Any] = [
                kTISPropertyInputSourceCategory as String: category as String,
                kTISPropertyInputSourceIsSelectCapable as String: true
            ]
            guard let list = TISCreateInputSourceList(filter as CFDictionary, false)?.takeRetainedValue() as? [TISInputSource] else {
                continue
            }
            for source in list {
                guard let id = getProperty(source, key: kTISPropertyInputSourceID),
                      let name = getProperty(source, key: kTISPropertyLocalizedName)
                else {
                    continue
                }
                sourcesById[id] = InputSource(id: id, name: name)
            }
        }
        return sourcesById.values.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    static func selectInputSource(id: String) {
        let filter: [String: Any] = [kTISPropertyInputSourceID as String: id]
        guard let list = TISCreateInputSourceList(filter as CFDictionary, false)?.takeRetainedValue() as? [TISInputSource],
              let source = list.first
        else {
            return
        }
        TISSelectInputSource(source)
    }

    static func currentInputSource() -> InputSource? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let id = getProperty(source, key: kTISPropertyInputSourceID),
              let name = getProperty(source, key: kTISPropertyLocalizedName)
        else {
            return nil
        }
        return InputSource(id: id, name: name)
    }

    static func resolveInputSourceId(_ value: String, in sources: [InputSource]) -> String? {
        if let match = sources.first(where: { $0.id == value }) {
            return match.id
        }
        if let candidates = builtinAliases[value] {
            for candidate in candidates {
                if let match = sources.first(where: { $0.id == candidate }) {
                    return match.id
                }
            }
        }
        return sources.first(where: { $0.displayName.localizedCaseInsensitiveCompare(value) == .orderedSame })?.id
    }

    static func displayName(for id: String, in sources: [InputSource]) -> String? {
        sources.first(where: { $0.id == id })?.displayName
    }

    private static func getProperty(_ source: TISInputSource, key: CFString) -> String? {
        guard let value = TISGetInputSourceProperty(source, key) else {
            return nil
        }
        return Unmanaged<CFString>.fromOpaque(value).takeUnretainedValue() as String
    }
}
