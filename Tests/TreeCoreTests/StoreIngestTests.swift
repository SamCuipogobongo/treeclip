import Testing
import Foundation
@testable import TreeCore

@Suite struct StoreIngestTests {
    /// A tiny text representation.
    private func text(_ s: String, uti: String = "public.utf8-plain-text") -> Representation {
        Representation(uti: uti, bytes: Data(s.utf8), isImage: false)
    }

    @Test func opensEmpty() async throws {
        let store = try Store.temporary()
        #expect(try await store.liveItemCount() == 0)
    }

    @Test func smallTextIsInlined() async throws {
        let store = try Store.temporary()
        let item = CapturedItem(
            kind: "text", title: "hello", contentHash: "h1",
            representations: [text("hello")]
        )
        let id = try await store.ingest(item, nowMillis: 1_000)

        #expect(try await store.liveItemCount() == 1)
        let rows = try await store.contentRows(itemId: id)
        #expect(rows.count == 1)
        #expect(rows[0].data != nil)          // inline
        #expect(rows[0].filePath == nil)      // not offloaded
        #expect(rows[0].bytes == 5)
    }

    @Test func largeTextIsOffloaded() async throws {
        let store = try Store.temporary()
        let big = String(repeating: "x", count: StorageThresholds.inlineMaxBytes + 1)
        let id = try await store.ingest(
            CapturedItem(kind: "text", title: "big", contentHash: "h2", representations: [text(big)]),
            nowMillis: 2_000
        )
        let rows = try await store.contentRows(itemId: id)
        #expect(rows[0].data == nil)          // not inline
        #expect(rows[0].filePath != nil)      // offloaded
        // file actually exists on disk
        let url = await store.payloadURL(relativePath: rows[0].filePath!)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func imageIsAlwaysOffloaded() async throws {
        let store = try Store.temporary()
        // Tiny image bytes — well under the inline threshold, but images always offload.
        let img = Representation(uti: "public.png", bytes: Data([0x89, 0x50, 0x4E, 0x47]), isImage: true)
        let id = try await store.ingest(
            CapturedItem(kind: "image", title: "shot", contentHash: "h3", representations: [img],
                         thumbnail: (data: Data([1, 2, 3]), w: 4, h: 4)),
            nowMillis: 3_000
        )
        let rows = try await store.contentRows(itemId: id)
        #expect(rows[0].data == nil)
        #expect(rows[0].filePath != nil)      // offloaded despite tiny size
        #expect(try await store.thumb(itemId: id)?.data == Data([1, 2, 3]))
    }

    @Test func duplicateBumpsInsteadOfInserting() async throws {
        let store = try Store.temporary()
        let make = { CapturedItem(kind: "text", title: "dup", contentHash: "same",
                                  representations: [self.text("dup")]) }
        let id1 = try await store.ingest(make(), nowMillis: 1_000)
        let id2 = try await store.ingest(make(), nowMillis: 5_000)

        #expect(id1 == id2)                                  // same row
        #expect(try await store.liveItemCount() == 1)        // no second insert
        let item = try await store.item(id: id1)
        #expect(item?.pasteCount == 2)                       // bumped
        #expect(item?.lastPastedAt == 5_000)                 // touched
        #expect(item?.firstCopiedAt == 1_000)                // preserved
    }
}
