import Foundation
import GRDB

// Read helpers. The projection-aware *list* query (threshold ②, never
// materializing large blobs) lands with M4's palette; these point reads are
// used by ingest callers and tests.
extension Store {
    public func item(id: String) throws -> Item? {
        try pool.read { db in try Item.fetchOne(db, key: id) }
    }

    public func contentRows(itemId: String) throws -> [ContentRow] {
        try pool.read { db in
            try ContentRow.filter(Column("itemId") == itemId).fetchAll(db)
        }
    }

    public func thumb(itemId: String) throws -> Thumb? {
        try pool.read { db in try Thumb.fetchOne(db, key: itemId) }
    }

    /// Absolute URL of an offloaded payload, for the paste/preview read paths.
    public func payloadURL(relativePath: String) -> URL {
        location.payloadsDirectory.appendingPathComponent(relativePath)
    }

    /// Materialize an item's full content for the paste/restore path — the one
    /// place we deliberately read payloads (inline bytes or offloaded file) back
    /// into memory, on explicit user action, not during browsing.
    public func loadContent(itemId: String) throws -> [(uti: String, bytes: Data)] {
        try contentRows(itemId: itemId).compactMap { row in
            if let inline = row.data { return (row.uti, inline) }
            if let path = row.filePath,
               let bytes = try? Data(contentsOf: payloadURL(relativePath: path)) {
                return (row.uti, bytes)
            }
            return nil
        }
    }

    /// Pin/unpin an item. Pinned items are exempt from both cap axes (§3.4).
    public func setPinned(id: String, pinned: Bool, nowMillis: Int64) throws {
        try pool.write { db in
            try db.execute(
                sql: "UPDATE item SET pinned = ?, updatedAt = ? WHERE id = ?",
                arguments: [pinned, nowMillis, id]
            )
        }
    }
}
