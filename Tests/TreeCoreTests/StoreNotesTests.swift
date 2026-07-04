import Testing
import Foundation
@testable import TreeCore

@Suite struct StoreNotesTests {
    @Test func createListUpdateDelete() async throws {
        let store = try Store.temporary()
        let id = try await store.createNote(body: "explain this diff", nowMillis: 1_000)
        #expect(try await store.listNotes().map(\.body) == ["explain this diff"])

        try await store.updateNoteBody(id: id, body: "explain this diff step by step", nowMillis: 1_100)
        #expect(try await store.note(id: id)?.body == "explain this diff step by step")

        try await store.deleteNote(id: id, nowMillis: 1_200)
        #expect(try await store.listNotes().isEmpty)
        #expect(try await store.note(id: id)?.deletedAt == 1_200)   // tombstone, not hard delete
    }

    @Test func newNotesSortToFront() async throws {
        let store = try Store.temporary()
        _ = try await store.createNote(body: "first", nowMillis: 1_000)
        _ = try await store.createNote(body: "second", nowMillis: 1_001)
        _ = try await store.createNote(body: "third", nowMillis: 1_002)
        #expect(try await store.listNotes().map(\.body) == ["third", "second", "first"])
    }

    @Test func promoteFromItemCarriesProvenance() async throws {
        let store = try Store.temporary()
        let itemId = try await store.ingest(CapturedItem(
            kind: "text", title: "reusable prompt", contentHash: "p",
            representations: [Representation(uti: "public.utf8-plain-text",
                                             bytes: Data("reusable prompt".utf8), isImage: false)]
        ), nowMillis: 1_000)
        let noteId = try #require(try await store.createNote(fromItemId: itemId, nowMillis: 2_000))
        let note = try #require(try await store.note(id: noteId))
        #expect(note.body == "reusable prompt")
        #expect(note.originItemId == itemId)
    }

    @Test func frameJSONPersists() async throws {
        let store = try Store.temporary()
        let id = try await store.createNote(body: "note", nowMillis: 1_000)
        try await store.updateNoteFrame(id: id, frameJSON: #"{"x":100,"y":200,"w":240,"h":160}"#, nowMillis: 1_100)
        #expect(try await store.note(id: id)?.panelFrame == #"{"x":100,"y":200,"w":240,"h":160}"#)
    }
}
