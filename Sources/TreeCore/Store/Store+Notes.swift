import Foundation
import GRDB

/// Floating-note CRUD (design §6). Notes are the prompt-snippets surface: short
/// reusable text pinned on screen. Same soft-delete / updatedAt discipline as
/// items (sync-ready). Frame geometry is opaque JSON owned by the UI layer.
extension Store {
    @discardableResult
    public func createNote(body: String, originItemId: String? = nil, nowMillis: Int64) throws -> String {
        let id = ID.generateV7(nowMillis: nowMillis)
        try pool.write { db in
            // New notes sort to the front (smallest order = first).
            let minOrder = try Double.fetchOne(db, sql:
                "SELECT MIN(sortOrder) FROM note WHERE deletedAt IS NULL") ?? 0
            var note = Note(id: id, body: body, originItemId: originItemId,
                            sortOrder: minOrder - 1, createdAt: nowMillis, updatedAt: nowMillis)
            try note.insert(db)
        }
        return id
    }

    /// Promote a history item into a note (carries provenance). Uses the item's
    /// title as the note body — snippets are text, so this is the plain preview.
    @discardableResult
    public func createNote(fromItemId itemId: String, nowMillis: Int64) throws -> String? {
        guard let item = try item(id: itemId) else { return nil }
        return try createNote(body: item.title, originItemId: itemId, nowMillis: nowMillis)
    }

    public func updateNoteBody(id: String, body: String, nowMillis: Int64) throws {
        try pool.write { db in
            try db.execute(sql: "UPDATE note SET body = ?, updatedAt = ? WHERE id = ?",
                           arguments: [body, nowMillis, id])
        }
    }

    /// Persist window geometry (opaque JSON) so notes reopen where the user left
    /// them across restarts.
    public func updateNoteFrame(id: String, frameJSON: String, nowMillis: Int64) throws {
        try pool.write { db in
            try db.execute(sql: "UPDATE note SET panelFrame = ?, updatedAt = ? WHERE id = ?",
                           arguments: [frameJSON, nowMillis, id])
        }
    }

    public func deleteNote(id: String, nowMillis: Int64) throws {
        try pool.write { db in
            try db.execute(sql: "UPDATE note SET deletedAt = ?, updatedAt = ? WHERE id = ?",
                           arguments: [nowMillis, nowMillis, id])
        }
    }

    /// All live notes, front-to-back by sort order.
    public func listNotes() throws -> [Note] {
        try pool.read { db in
            try Note.filter(Column("deletedAt") == nil)
                .order(Column("sortOrder").asc)
                .fetchAll(db)
        }
    }

    public func note(id: String) throws -> Note? {
        try pool.read { db in try Note.fetchOne(db, key: id) }
    }
}
