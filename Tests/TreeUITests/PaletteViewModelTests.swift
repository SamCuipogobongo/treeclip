import Testing
import Foundation
@testable import TreeUI
import TreeCore

@MainActor
@Suite struct PaletteViewModelTests {
    private func seededStore(_ n: Int) async throws -> Store {
        let store = try Store.temporary(config: .init(maxItems: 10_000, maxAgeDays: nil))
        for k in 0..<n {
            try await store.ingest(CapturedItem(
                kind: "text", title: "clip \(k)", contentHash: "h\(k)",
                representations: [Representation(uti: "public.utf8-plain-text",
                                                 bytes: Data("clip \(k)".utf8), isImage: false)]
            ), nowMillis: Int64(1_000 + k))
        }
        return store
    }

    @Test func reloadShowsNewestFirst() async throws {
        let vm = PaletteViewModel(store: try await seededStore(3))
        await vm.reload()
        #expect(vm.rows.map(\.title) == ["clip 2", "clip 1", "clip 0"])
        #expect(vm.selectedIndex == 0)
    }

    @Test func selectionMovesAndClamps() async throws {
        let vm = PaletteViewModel(store: try await seededStore(3))
        await vm.reload()
        vm.moveUp()                       // already at top, no-op
        #expect(vm.selectedIndex == 0)
        vm.moveDown(); vm.moveDown()
        #expect(vm.selectedIndex == 2)
        vm.moveDown()                     // at bottom, clamps
        #expect(vm.selectedIndex == 2)
        #expect(vm.selectedRow?.title == "clip 0")
    }

    @Test func searchFiltersToMatches() async throws {
        let store = try await seededStore(5)
        try await store.ingest(CapturedItem(
            kind: "text", title: "deploy kraken", contentHash: "kr",
            representations: [Representation(uti: "public.utf8-plain-text",
                                             bytes: Data("deploy kraken".utf8), isImage: false)]
        ), nowMillis: 9_999)
        let vm = PaletteViewModel(store: store)
        vm.query = "kraken"
        await vm.reload()
        #expect(vm.rows.count == 1)
        #expect(vm.selectedRow?.title == "deploy kraken")
    }

    @Test func staleSelectionReclampsAfterShrinkingReload() async throws {
        let store = try await seededStore(5)
        let vm = PaletteViewModel(store: store)
        await vm.reload()
        vm.select(4)                      // last of 5
        #expect(vm.selectedIndex == 4)
        vm.query = "clip 0"               // narrows to fewer rows
        await vm.reload()
        #expect(vm.selectedIndex < vm.rows.count)   // reclamped, no out-of-bounds
    }
}
