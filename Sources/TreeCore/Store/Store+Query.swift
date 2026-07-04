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
}
