import Foundation
import Testing
@testable import AutoImeSwitcher

final class MappingStoreTests {
    @Test func testUnavailableSourceSurvivesSaveAndReload() throws {
        let config = ConfigFile(entries: [ConfigEntry(bundleId: "example.app", inputSourceId: "missing.ime", inputSourceName: "Custom IME")])
        let updated = ConfigFile.updated(mappings: config.mappings(availableSources: []), sources: [], previous: config)
        let decoded = try JSONDecoder().decode(ConfigFile.self, from: JSONEncoder().encode(updated))
        #expect(decoded.entries.first?.inputSourceId == "missing.ime")
        #expect(decoded.entries.first?.inputSourceName == "Custom IME")
        #expect(decoded.mappings(availableSources: []) == ["example.app": "missing.ime"])
    }

    @Test func testLegacyNameOnlyEntryIsPreservedUntilSourceReturns() {
        let config = ConfigFile(entries: [ConfigEntry(bundleId: "example.app", inputSourceId: nil, inputSourceName: "拼音")])
        let updated = ConfigFile.updated(mappings: config.mappings(availableSources: []), sources: [], previous: config)
        #expect(updated.entries.first?.inputSourceId == nil)
        #expect(updated.entries.first?.inputSourceName == "拼音")
        let sources = [InputSource(id: "com.apple.inputmethod.SCIM.ITABC", name: "Pinyin")]
        #expect(updated.mappings(availableSources: sources)["example.app"] == sources[0].id)
    }

    @Test func testRemovingOneRulePreservesOtherUnavailableRules() {
        let config = ConfigFile(entries: [
            ConfigEntry(bundleId: "first", inputSourceId: "missing", inputSourceName: "Custom"),
            ConfigEntry(bundleId: "second", inputSourceId: "ABC", inputSourceName: "ABC")
        ])
        let updated = ConfigFile.updated(mappings: ["first": "missing"], sources: [], previous: config)
        #expect(updated.entries.count == 1)
        #expect(updated.entries.first?.inputSourceName == "Custom")
    }

    @Test func testExactIdWinsOverAliasAndLocalizedName() {
        let sources = [InputSource(id: "ABC", name: "Custom"), InputSource(id: "com.apple.keylayout.ABC", name: "ABC")]
        #expect(InputSourceManager.resolveInputSourceId("ABC", in: sources) == "ABC")
    }

    @Test func testMalformedConfigurationDoesNotDecodeAsEmptyRules() {
        #expect(throws: (any Error).self) { try JSONDecoder().decode(ConfigFile.self, from: Data("{broken}".utf8)) }
    }
}
