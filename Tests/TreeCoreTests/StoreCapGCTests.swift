import Testing
import Foundation
@testable import TreeCore

@Suite struct StoreCapGCTests {
    private func textItem(_ n: Int) -> CapturedItem {
        CapturedItem(kind: "text", title: "t\(n)", contentHash: "h\(n)",
                     representations: [Representation(uti: "public.utf8-plain-text",
                                                      bytes: Data("t\(n)".utf8), isImage: false)])
    }

    @Test func countCapTombstonesOldestNonPinned() async throws {
        let store = try Store.temporary(config: .init(maxItems: 3, maxAgeDays: nil))
        for n in 0..<5 { try await store.ingest(textItem(n), nowMillis: Int64(1_000 + n)) }
        // Only the newest 3 remain live.
        #expect(try await store.liveItemCount() == 3)
        let ids = try await store.listItems(limit: 10).map(\.title)
        #expect(ids == ["t4", "t3", "t2"])   // newest-first, oldest trimmed
    }

    @Test func pinnedIsExemptFromCountCap() async throws {
        let store = try Store.temporary(config: .init(maxItems: 2, maxAgeDays: nil))
        let pinnedId = try await store.ingest(textItem(0), nowMillis: 1_000)
        try await store.setPinned(id: pinnedId, pinned: true, nowMillis: 1_000)
        for n in 1..<5 { try await store.ingest(textItem(n), nowMillis: Int64(1_000 + n)) }
        // Pinned survives even though it is the oldest.
        let titles = try await store.listItems(limit: 10).map(\.title)
        #expect(titles.contains("t0"))
        #expect(try await store.item(id: pinnedId)?.deletedAt == nil)
    }

    @Test func expiryUsesLastPastedNotCreation() async throws {
        let dayMs: Int64 = 86_400_000
        let store = try Store.temporary(config: .init(maxItems: 1000, maxAgeDays: 30))
        // Two old items; one gets re-pasted (dedup bump) to refresh lastPastedAt.
        let hotId = try await store.ingest(textItem(0), nowMillis: 0)
        try await store.ingest(textItem(1), nowMillis: 0)
        let now = 40 * dayMs
        _ = try await store.ingest(textItem(0), nowMillis: now)   // bump hot item to now

        try await store.enforceExpiry(nowMillis: now)
        // Cold item (t1, last paste at 0) expired; hot item (t0, bumped) survives.
        #expect(try await store.item(id: hotId)?.deletedAt == nil)
        #expect(try await store.liveItemCount() == 1)
    }

    @Test func gcHardDeletesFilesAndRows() async throws {
        let store = try Store.temporary()
        let big = String(repeating: "x", count: StorageThresholds.inlineMaxBytes + 1)
        let id = try await store.ingest(
            CapturedItem(kind: "text", title: "big", contentHash: "big",
                         representations: [Representation(uti: "public.utf8-plain-text",
                                                          bytes: Data(big.utf8), isImage: false)]),
            nowMillis: 1_000)
        let rows = try await store.contentRows(itemId: id)
        let fileURL = await store.payloadURL(relativePath: rows[0].filePath!)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        try await store.softDelete(id: id, nowMillis: 2_000)
        #expect(try await store.liveItemCount() == 0)          // gone from live view
        #expect(try await store.item(id: id) != nil)           // but row still there (tombstone)

        let reclaimed = try await store.runGC()
        #expect(reclaimed == 1)
        #expect(try await store.item(id: id) == nil)           // row hard-deleted
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))  // file gone
    }

    @Test func gcIsIdempotentWhenNothingTombstoned() async throws {
        let store = try Store.temporary()
        try await store.ingest(textItem(0), nowMillis: 1_000)
        #expect(try await store.runGC() == 0)
        #expect(try await store.runGC() == 0)
        #expect(try await store.liveItemCount() == 1)
    }

    @Test func searchFindsByTitle() async throws {
        let store = try Store.temporary()
        try await store.ingest(
            CapturedItem(kind: "text", title: "deploy the kraken", contentHash: "k",
                         representations: [Representation(uti: "public.utf8-plain-text",
                                                          bytes: Data("deploy the kraken".utf8), isImage: false)]),
            nowMillis: 1_000)
        try await store.ingest(textItem(99), nowMillis: 1_001)
        let hits = try await store.search("kraken", limit: 10)
        #expect(hits.count == 1)
        #expect(hits[0].title == "deploy the kraken")
    }

    @Test func orphanFilesAreReclaimed() async throws {
        let store = try Store.temporary()
        // Simulate an orphan: a payload dir whose item never got inserted.
        let orphanDir = await store.payloadURL(relativePath: "ghost-id")
        try FileManager.default.createDirectory(at: orphanDir, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: orphanDir.appendingPathComponent("public.png"))

        let removed = try await store.reclaimOrphanFiles()
        #expect(removed == 1)
        #expect(!FileManager.default.fileExists(atPath: orphanDir.path))
    }
}
