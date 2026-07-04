import Foundation
import GRDB

/// History capping (design §3.4). Operates on a `Database` inside the caller's
/// transaction so the count cap runs synchronously on the write path (Flycut:
/// trim at insert time, never "clean up later"). Trimming = tombstone only;
/// the heavy work (deleting BLOBs and files) is deferred to `runGC` at idle
/// (Ditto: big-BLOB deletes must be async + batched).
enum CapEnforcer {
    /// Tombstone the oldest live non-pinned items beyond `maxItems`.
    static func enforceCountCap(_ db: Database, maxItems: Int, nowMillis: Int64) throws {
        let overflow = try String.fetchAll(db, sql: """
            SELECT id FROM item
            WHERE deletedAt IS NULL AND pinned = 0
            ORDER BY lastPastedAt DESC
            LIMIT -1 OFFSET ?
            """, arguments: [maxItems])
        try tombstone(db, ids: overflow, nowMillis: nowMillis)
    }

    /// Tombstone live non-pinned items whose `lastPastedAt` is older than the
    /// age cap (uses last-paste, not creation, so hot items never expire).
    static func enforceExpiry(_ db: Database, maxAgeDays: Int, nowMillis: Int64) throws {
        let cutoff = nowMillis - Int64(maxAgeDays) * 86_400_000
        let expired = try String.fetchAll(db, sql: """
            SELECT id FROM item
            WHERE deletedAt IS NULL AND pinned = 0 AND lastPastedAt < ?
            """, arguments: [cutoff])
        try tombstone(db, ids: expired, nowMillis: nowMillis)
    }

    static func tombstone(_ db: Database, ids: [String], nowMillis: Int64) throws {
        guard !ids.isEmpty else { return }
        let placeholders = databaseQuestionMarks(count: ids.count)
        try db.execute(
            sql: "UPDATE item SET deletedAt = ?, updatedAt = ? WHERE id IN (\(placeholders))",
            arguments: StatementArguments([nowMillis, nowMillis] + ids)
        )
    }
}

/// `?,?,...` of the given length for an `IN` clause.
func databaseQuestionMarks(count: Int) -> String {
    Array(repeating: "?", count: count).joined(separator: ",")
}
