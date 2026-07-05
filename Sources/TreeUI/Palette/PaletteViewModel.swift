import Foundation
import Observation
import TreeCore

/// Drives the palette: current query, the rows to show, and keyboard selection.
/// Deliberately free of SwiftUI/AppKit so the interaction logic (search routing,
/// selection movement, clamping) is unit-tested without a window server.
@MainActor
@Observable
public final class PaletteViewModel {
    private let store: Store
    public private(set) var rows: [ListRow] = []
    public var query: String = ""
    /// nil = all types; otherwise link/code/color/plain/image/file.
    public private(set) var categoryFilter: String?
    public private(set) var selectedIndex: Int = 0

    /// Max rows fetched per view (first screen + a buffer; the store pages).
    public var pageLimit: Int = 200

    public init(store: Store) { self.store = store }

    /// Reload rows for the current query: empty → recent history, else FTS.
    public func reload() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let result: [ListRow]
        if q.isEmpty {
            result = (try? await store.listItems(limit: pageLimit, category: categoryFilter)) ?? []
        } else {
            result = (try? await store.search(q, limit: pageLimit, category: categoryFilter)) ?? []
        }
        rows = result
        clampSelection()
    }

    /// Set the type filter (nil = all) and reload.
    public func setCategoryFilter(_ category: String?) async {
        categoryFilter = category
        await reload()
    }

    public func moveDown() { if selectedIndex < rows.count - 1 { selectedIndex += 1 } }
    public func moveUp() { if selectedIndex > 0 { selectedIndex -= 1 } }
    public func select(_ index: Int) { selectedIndex = index; clampSelection() }

    public var selectedRow: ListRow? {
        rows.indices.contains(selectedIndex) ? rows[selectedIndex] : nil
    }

    private func clampSelection() {
        selectedIndex = rows.isEmpty ? 0 : min(max(0, selectedIndex), rows.count - 1)
    }
}
