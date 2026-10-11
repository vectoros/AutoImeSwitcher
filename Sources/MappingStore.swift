import Foundation

struct ConfigFile: Codable {
    var entries: [ConfigEntry]

    func mappings(availableSources: [InputSource]) -> [String: String] {
        var result: [String: String] = [:]
        for entry in entries where !entry.bundleId.isEmpty {
            let candidates = [entry.inputSourceId, entry.inputSourceName].compactMap { $0 }.filter { !$0.isEmpty }
            // Keep unavailable sources so a temporary removal never deletes the user's rule.
            if let value = candidates.compactMap({ InputSourceManager.resolveInputSourceId($0, in: availableSources) }).first
                ?? candidates.first {
                result[entry.bundleId] = value
            }
        }
        return result
    }

    static func updated(mappings: [String: String], sources: [InputSource], previous: ConfigFile) -> ConfigFile {
        ConfigFile(entries: mappings.sorted { $0.key < $1.key }.map { bundleId, sourceId in
            if let old = previous.entries.first(where: { $0.bundleId == bundleId }),
               (old.inputSourceId == sourceId || (old.inputSourceId == nil && old.inputSourceName == sourceId)),
               InputSourceManager.resolveInputSourceId(sourceId, in: sources) == nil {
                return old
            }
            return ConfigEntry(bundleId: bundleId, inputSourceId: sourceId,
                               inputSourceName: InputSourceManager.displayName(for: sourceId, in: sources))
        })
    }
}

struct ConfigEntry: Codable {
    let bundleId: String
    let inputSourceId: String?
    let inputSourceName: String?
}
