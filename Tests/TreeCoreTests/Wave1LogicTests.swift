import Testing
import Foundation
@testable import TreeCore

@Suite struct FilterExtraRulesTests {
    @Test func ignoredPasteboardTypeSuppresses() {
        let cfg = FilterConfig(ignoredTypes: ["com.agilebits.onepassword"])
        let decision = FilterChain.decide(
            flags: [], sourceApp: nil,
            presentUTIs: ["public.utf8-plain-text", "com.agilebits.onepassword"],
            text: "hunter2", totalBytes: 7, config: cfg)
        #expect(decision == .ignore(reason: "ignoredType"))
    }

    @Test func ignoreRegexSuppressesMatchingText() {
        let cfg = FilterConfig(ignoreRegex: "^sk-[A-Za-z0-9]+$")
        #expect(FilterChain.decide(flags: [], sourceApp: nil, presentUTIs: ["public.utf8-plain-text"],
                                   text: "sk-abc123", totalBytes: 9, config: cfg)
                == .ignore(reason: "regex"))
        // non-matching text still captures
        #expect(FilterChain.decide(flags: [], sourceApp: nil, presentUTIs: ["public.utf8-plain-text"],
                                   text: "hello world", totalBytes: 11, config: cfg) == .capture)
    }

    @Test func invalidRegexNeverSuppresses() {
        let cfg = FilterConfig(ignoreRegex: "[unclosed(")
        #expect(FilterChain.decide(flags: [], sourceApp: nil, presentUTIs: [],
                                   text: "anything", totalBytes: 8, config: cfg) == .capture)
    }
}

@Suite struct StoreClearTests {
    private func text(_ n: Int) -> CapturedItem {
        CapturedItem(kind: "text", title: "t\(n)", contentHash: "h\(n)",
                     representations: [Representation(uti: "public.utf8-plain-text",
                                                      bytes: Data("t\(n)".utf8), isImage: false)])
    }

    @Test func clearKeepsPinned() async throws {
        let store = try Store.temporary(config: .init(maxItems: 100, maxAgeDays: nil))
        let pinned = try await store.ingest(text(0), nowMillis: 1_000)
        try await store.setPinned(id: pinned, pinned: true, nowMillis: 1_000)
        for n in 1..<4 { try await store.ingest(text(n), nowMillis: Int64(1_000 + n)) }

        let cleared = try await store.clear(keepPinned: true, nowMillis: 5_000)
        #expect(cleared == 3)                                   // the 3 unpinned
        let live = try await store.listItems(limit: 10)
        #expect(live.map(\.title) == ["t0"])                    // pinned survives
    }

    @Test func clearAllRemovesEverything() async throws {
        let store = try Store.temporary(config: .init(maxItems: 100, maxAgeDays: nil))
        let pinned = try await store.ingest(text(0), nowMillis: 1_000)
        try await store.setPinned(id: pinned, pinned: true, nowMillis: 1_000)
        try await store.ingest(text(1), nowMillis: 1_001)

        let cleared = try await store.clear(keepPinned: false, nowMillis: 5_000)
        #expect(cleared == 2)                                   // pinned included
        #expect(try await store.listItems(limit: 10).isEmpty)
    }
}
