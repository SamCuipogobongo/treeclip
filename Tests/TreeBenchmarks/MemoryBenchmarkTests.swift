import Testing
import Foundation
@testable import TreeCore

/// The memory gate. Turns treeclip's headline promise — "a clipboard that
/// doesn't bloat" — into CI-enforced assertions (implement.md M3, PRD).
///
/// These are *delta* assertions, not absolute RSS ceilings: they seed hundreds
/// of MB of image payload on disk and assert the process's memory barely moves.
/// That is the anti-Maccy invariant (Maccy's RSS tracks total history bytes
/// because it inlines images and hydrates everything; treeclip offloads and
/// projects, so payload never enters memory). They are self-proving: change
/// `listItems` to SELECT `content.data` and `paletteScrollHoldsNoPayload` fails.
@Suite struct MemoryBenchmarkTests {
    // Generous headroom (≈4× expected) so normal allocator noise never flakes,
    // while a real regression (loading payloads) blows past by a wide margin.
    private let images = 600
    private let imageBytes = 256 * 1024          // ~150MB of payload on disk total

    private func settle() { for _ in 0..<3 { autoreleasepool {} } }

    @Test func residencyDoesNotScaleWithPayload() async throws {
        let store = try Store.temporary(config: .init(maxItems: 10_000, maxAgeDays: nil))
        settle()
        let baseline = MemoryProbe.residentBytes()

        // 3000 items, every 5th a 256KB image → ~150MB of payload written to disk.
        try await store.seedFixture(itemCount: 3000, imageEveryN: 5,
                                    imageBytes: imageBytes, thumbBytes: 4096,
                                    baseMillis: 1_000_000)
        // Warm idle: render the palette a few times (projection path).
        for _ in 0..<5 { _ = try await store.listItems(limit: 200) }
        settle()

        let delta = MemoryProbe.residentBytes() - baseline
        let payloadOnDisk = images * imageBytes
        print("[mem] 3000-item warm idle: RSS +\(delta / 1_048_576)MB vs \(payloadOnDisk / 1_048_576)MB payload on disk")
        // RSS is whole-process and swift-testing runs suites in parallel, so a
        // sibling test loading a heavy framework (e.g. Vision) inflates this
        // shared number. 100MB still proves the 150MB payload isn't materialized
        // and catches the real regression (loading payloads adds ~125MB — see
        // the self-proof in the session log).
        #expect(delta < 100 * 1024 * 1024,
                "RSS grew \(delta / 1_048_576)MB against \(payloadOnDisk / 1_048_576)MB payload on disk")
    }

    @Test func paletteScrollHoldsNoPayload() async throws {
        let store = try Store.temporary(config: .init(maxItems: 10_000, maxAgeDays: nil))
        try await store.seedFixture(itemCount: 1000, imageEveryN: 2,
                                    imageBytes: imageBytes, thumbBytes: 4096,
                                    baseMillis: 1_000_000)
        settle()
        let before = MemoryProbe.residentBytes()

        // Scroll the whole history in pages — the list must only touch thumbnails.
        for offset in stride(from: 0, to: 1000, by: 100) {
            _ = try await store.listItems(limit: 100, offset: offset)
        }
        settle()

        let delta = MemoryProbe.residentBytes() - before
        print("[mem] paging 1000-item list: RSS +\(delta / 1_048_576)MB")
        // Headroom for parallel-suite RSS pollution (see note above); still far
        // below the payload and trips on a real materialization regression.
        #expect(delta < 40 * 1024 * 1024,
                "paging the list grew RSS by \(delta / 1_048_576)MB — payload leaking into the list?")
    }

    @Test func clearReclaimsDiskPayload() async throws {
        let store = try Store.temporary(config: .init(maxItems: 10_000, maxAgeDays: nil))
        try await store.seedFixture(itemCount: 500, imageEveryN: 2,
                                    imageBytes: imageBytes, thumbBytes: 4096,
                                    baseMillis: 1_000_000)
        let ids = try await store.listItems(limit: 1000).map(\.id)
        for id in ids { try await store.softDelete(id: id, nowMillis: 2_000_000) }

        var reclaimed = 0
        while true {
            let n = try await store.runGC(batchLimit: 200)
            if n == 0 { break }
            reclaimed += n
        }
        #expect(reclaimed == ids.count)
        #expect(try await store.liveItemCount() == 0)
        // Payload directory fully reclaimed (nothing left on disk).
        let remainingOrphans = try await store.reclaimOrphanFiles()
        #expect(remainingOrphans == 0)
    }
}
