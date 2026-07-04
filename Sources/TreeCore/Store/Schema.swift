import Foundation
import GRDB

// Schema v1 (design.md §3.2). Column names are camelCase to match the Swift
// record properties 1:1 (GRDB's default Codable mapping) — SQLite is
// case-insensitive on identifiers, so this stays readable while avoiding a
// layer of CodingKeys boilerplate. Once shipped, v1 is frozen: any change lands
// as a new registered migration, never an edit here.
enum Schema {
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        // In DEBUG, fail loudly if a shipped migration is ever mutated.
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = false
        #endif

        migrator.registerMigration("v1") { db in
            // auto_vacuum must be set on an empty database (before any table).
            try db.execute(sql: "PRAGMA auto_vacuum = INCREMENTAL")

            try db.create(table: "item") { t in
                t.primaryKey("id", .text)
                t.column("kind", .text).notNull()
                t.column("title", .text).notNull()
                t.column("contentHash", .text).notNull()
                t.column("sourceApp", .text)
                t.column("firstCopiedAt", .integer).notNull()
                t.column("lastPastedAt", .integer).notNull()
                t.column("pasteCount", .integer).notNull().defaults(to: 0)
                t.column("pinned", .boolean).notNull().defaults(to: false)
                t.column("deletedAt", .integer)
                t.column("updatedAt", .integer).notNull()
            }
            // Dedup only among live rows: a tombstoned item must not block a
            // re-copy of the same content from creating a fresh entry.
            try db.create(
                index: "idx_item_hash", on: "item",
                columns: ["contentHash"], unique: true,
                condition: Column("deletedAt") == nil
            )
            try db.create(index: "idx_item_lastPasted", on: "item", columns: ["lastPastedAt"])

            try db.create(table: "content") { t in
                t.column("itemId", .text).notNull()
                    .references("item", onDelete: .cascade)
                t.column("uti", .text).notNull()
                t.column("data", .blob)          // inline (≤64KB) XOR filePath
                t.column("filePath", .text)
                t.column("bytes", .integer).notNull()
                t.primaryKey(["itemId", "uti"])
            }

            try db.create(table: "thumb") { t in
                t.primaryKey("itemId", .text)
                    .references("item", onDelete: .cascade)
                t.column("data", .blob).notNull()
                t.column("w", .integer).notNull()
                t.column("h", .integer).notNull()
            }

            try db.create(table: "note") { t in
                t.primaryKey("id", .text)
                t.column("body", .text).notNull()
                t.column("panelFrame", .text)
                t.column("originItemId", .text)
                t.column("sortOrder", .double).notNull()
                t.column("createdAt", .integer).notNull()
                t.column("updatedAt", .integer).notNull()
                t.column("deletedAt", .integer)
            }

            // Full-text search over title + OCR text. item_id is stored but not
            // indexed so search results map back to the owning item.
            try db.create(virtualTable: "item_fts", using: FTS5()) { t in
                t.column("item_id").notIndexed()
                t.column("title")
                t.column("ocr_text")
            }
        }

        return migrator
    }
}
