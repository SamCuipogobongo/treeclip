import AppKit
import TreeCore
import TreeUI
import TreeCapture

/// Owns the live set of floating note panels: restores them on launch, creates
/// new ones, and bridges each panel's edits/paste/delete to the store and the
/// paste engine. One place so the app delegate stays thin.
@MainActor
final class NotesController {
    private let store: Store
    private let pasteEngine: PasteEngine
    private var panels: [String: NotePanel] = [:]

    init(store: Store, pasteEngine: PasteEngine) {
        self.store = store
        self.pasteEngine = pasteEngine
    }

    func restore() async {
        for note in (try? await store.listNotes()) ?? [] { addPanel(for: note) }
    }

    func newNote() async {
        guard let id = try? await store.createNote(body: "", nowMillis: nowMillis()),
              let note = try? await store.note(id: id) else { return }
        addPanel(for: note)
        panels[id]?.makeKeyAndOrderFront(nil)
    }

    func promote(itemId: String) async {
        guard let id = try? await store.createNote(fromItemId: itemId, nowMillis: nowMillis()),
              let note = try? await store.note(id: id) else { return }
        addPanel(for: note)
    }

    private func addPanel(for note: Note) {
        let panel = NotePanel(note: note)
        let id = note.id
        panel.onBodyChange = { [weak self] body in
            Task { try? await self?.store.updateNoteBody(id: id, body: body, nowMillis: nowMillis()) }
        }
        panel.onFrameChange = { [weak self] frame in
            guard let json = frame.jsonString() else { return }
            Task { try? await self?.store.updateNoteFrame(id: id, frameJSON: json, nowMillis: nowMillis()) }
        }
        panel.onPaste = { [weak self] in
            guard let self else { return }
            Task {
                if let note = try? await self.store.note(id: id) {
                    await self.pasteEngine.pasteText(note.body, forceRaw: false, nowMillis: nowMillis())
                }
            }
        }
        panel.onDelete = { [weak self] in Task { await self?.delete(id) } }
        panels[id] = panel
        panel.show()
    }

    private func delete(_ id: String) async {
        try? await store.deleteNote(id: id, nowMillis: nowMillis())
        if let panel = panels.removeValue(forKey: id) {
            panel.delegate = nil
            panel.close()
        }
    }
}

func nowMillis() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
