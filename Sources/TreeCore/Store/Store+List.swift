import Foundation
import GRDB

/// A row for the palette list. Carries only metadata + the pre-generated
/// thumbnail — never the original payload. This is the projection discipline
/// (design §3.3, threshold ②): the list query never joins `content`, so large
/// blobs cannot be materialized into memory during scroll, by construction.
public struct ListRow: Sendable, Identifiable {
    public var id: String
    public var kind: String
    public var title: String
    public var pinned: Bool
    public var lastPastedAt: Int64
    public var thumb: Data?
    public var category: String?
}

extension Store {
    /// Paginated history for the palette. `content.data` is never touched.
    /// `category` filters to one type (link/code/color/plain/image/file).
    public func listItems(limit: Int, offset: Int = 0, category: String? = nil) throws -> [ListRow] {
        try pool.read { db in
            let filter = category != nil ? "AND i.category = ?" : ""
            let sql = """
                SELECT i.id, i.kind, i.title, i.pinned, i.lastPastedAt, i.category, t.data AS thumb
                FROM item i
                LEFT JOIN thumb t ON t.itemId = i.id
                WHERE i.deletedAt IS NULL \(filter)
                ORDER BY i.pinned DESC, i.lastPastedAt DESC
                LIMIT ? OFFSET ?
                """
            let args: StatementArguments = category != nil ? [category, limit, offset] : [limit, offset]
            return try Row.fetchAll(db, sql: sql, arguments: args).map(Self.listRow)
        }
    }

    /// FTS search over title + OCR text, newest-first among matches.
    public func search(_ query: String, limit: Int, category: String? = nil) throws -> [ListRow] {
        guard let pattern = FTS5Pattern(matchingAllTokensIn: query) else { return [] }
        return try pool.read { db in
            let filter = category != nil ? "AND i.category = ?" : ""
            let sql = """
                SELECT i.id, i.kind, i.title, i.pinned, i.lastPastedAt, i.category, t.data AS thumb
                FROM item_fts f
                JOIN item i ON i.id = f.item_id
                LEFT JOIN thumb t ON t.itemId = i.id
                WHERE f.item_fts MATCH ? AND i.deletedAt IS NULL \(filter)
                ORDER BY i.lastPastedAt DESC
                LIMIT ?
                """
            let args: StatementArguments = category != nil ? [pattern, category, limit] : [pattern, limit]
            return try Row.fetchAll(db, sql: sql, arguments: args).map(Self.listRow)
        }
    }

    private static func listRow(_ row: Row) -> ListRow {
        ListRow(
            id: row["id"], kind: row["kind"], title: row["title"],
            pinned: row["pinned"], lastPastedAt: row["lastPastedAt"],
            thumb: row["thumb"], category: row["category"]
        )
    }
}
