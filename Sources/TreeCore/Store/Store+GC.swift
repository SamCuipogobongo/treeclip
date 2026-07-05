import Foundation
import GRDB

// Deletion + garbage collection (design §3.4). Tombstone is cheap and
// synchronous; reclaiming BLOBs/files is batched and meant to run at idle.
extension Store {
    /// User-initiated delete: tombstone now, reclaim later.
    public func softDelete(id: String, nowMillis: Int64) throws {
        try pool.write { db in
            try CapEnforcer.tombstone(db, ids: [id], nowMillis: nowMillis)
        }
    }

    /// Clear history in one shot. `keepPinned: true` is the everyday "Clear"
    /// (pins survive); `false` is "Clear All". Tombstones only — GC reclaims the
    /// files/rows at idle. Returns the number of items cleared.
    @discardableResult
    public func clear(keepPinned: Bool, nowMillis: Int64) throws -> Int {
        try pool.write { db in
            let sql = keepPinned
                ? "UPDATE item SET deletedAt = ?, updatedAt = ? WHERE deletedAt IS NULL AND pinned = 0"
                : "UPDATE item SET deletedAt = ?, updatedAt = ? WHERE deletedAt IS NULL"
            try db.execute(sql: sql, arguments: [nowMillis, nowMillis])
            return db.changesCount
        }
    }

    /// Apply the age-based expiry axis (call periodically, e.g. daily).
    public func enforceExpiry(nowMillis: Int64) throws {
        guard let maxAgeDays = config.maxAgeDays else { return }
        try pool.write { db in
            try CapEnforcer.enforceExpiry(db, maxAgeDays: maxAgeDays, nowMillis: nowMillis)
        }
    }

    /// Hard-delete a batch of tombstoned items: remove their payload files, then
    /// their rows (cascade drops content/thumb) + FTS entries, then reclaim
    /// pages via incremental_vacuum. Returns the number of items reclaimed.
    /// Batched + idle-driven so large-BLOB deletes never lock the DB (Ditto).
    @discardableResult
    public func runGC(batchLimit: Int = 200) throws -> Int {
        let ids = try pool.read { db in
            try String.fetchAll(db, sql: "SELECT id FROM item WHERE deletedAt IS NOT NULL LIMIT ?",
                                arguments: [batchLimit])
        }
        guard !ids.isEmpty else { return 0 }

        // Files first (idempotent): a crash mid-GC leaves rows that the next
        // pass re-picks up; deleting files before rows never dangles a row.
        for id in ids {
            let dir = location.payloadsDirectory.appendingPathComponent(id, isDirectory: true)
            try? FileManager.default.removeItem(at: dir)
        }

        try pool.write { db in
            let placeholders = databaseQuestionMarks(count: ids.count)
            try db.execute(sql: "DELETE FROM item_fts WHERE item_id IN (\(placeholders))",
                           arguments: StatementArguments(ids))
            try db.execute(sql: "DELETE FROM item WHERE id IN (\(placeholders))",
                           arguments: StatementArguments(ids))
            try db.execute(sql: "PRAGMA incremental_vacuum")
        }
        return ids.count
    }

    /// Reclaim payload directories with no owning item row — orphans left by a
    /// write that wrote files but failed before/around the insert (design §3.4).
    @discardableResult
    public func reclaimOrphanFiles() throws -> Int {
        let fm = FileManager.default
        let dirs = (try? fm.contentsOfDirectory(
            at: location.payloadsDirectory, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        let existing = try pool.read { db in
            Set(try String.fetchAll(db, sql: "SELECT id FROM item"))
        }
        var removed = 0
        for dir in dirs where !existing.contains(dir.lastPathComponent) {
            try? fm.removeItem(at: dir)
            removed += 1
        }
        return removed
    }
}
