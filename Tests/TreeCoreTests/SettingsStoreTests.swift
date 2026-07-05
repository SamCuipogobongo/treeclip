import Testing
import Foundation
@testable import TreeCore

@Suite struct SettingsStoreTests {
    private func freshStore() -> (SettingsStore, UserDefaults) {
        let suite = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (SettingsStore(defaults: defaults), defaults)
    }

    @Test func loadReturnsDefaultsWhenEmpty() {
        let (store, _) = freshStore()
        #expect(store.load() == AppSettings())
    }

    @Test func saveThenLoadRoundTrips() {
        let (store, _) = freshStore()
        var s = AppSettings()
        s.maxItems = 5000
        s.ignoreRegex = "^sk-"
        s.launchAtLogin = true
        s.maxAgeDays = 0
        store.save(s)
        #expect(store.load() == s)
    }

    @Test func mapsOntoRuntimeConfigs() {
        var s = AppSettings(maxItems: 42, maxAgeDays: 0)
        s.ignoredApps = ["com.apple.Safari"]
        s.ignoreRegex = ""
        s.terminalApps = ["com.apple.Terminal"]
        s.handoffMaxLines = 10

        #expect(s.storeConfig.maxItems == 42)
        #expect(s.storeConfig.maxAgeDays == nil)
        #expect(s.filterConfig.ignoredApps == ["com.apple.Safari"])
        #expect(s.filterConfig.ignoreRegex == nil)               // empty → nil
        #expect(s.agentRouteConfig.terminalApps == ["com.apple.Terminal"])
        #expect(s.agentRouteConfig.maxInlineLines == 10)
    }

    @Test func decodesMissingFieldsAsDefaults() throws {
        // Simulate an older payload missing newer keys.
        let (store, defaults) = freshStore()
        let partial = #"{"maxItems": 7}"#.data(using: .utf8)!
        defaults.set(partial, forKey: "appSettings")
        let loaded = store.load()
        #expect(loaded.maxItems == 7)                            // present key honored
        #expect(loaded.checkInterval == AppSettings().checkInterval)   // missing → default
        #expect(loaded.terminalApps == AppSettings().terminalApps)
    }
}
