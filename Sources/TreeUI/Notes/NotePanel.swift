import AppKit
import SwiftUI
import TreeCore

/// A floating, non-activating panel hosting one note. Persists its frame on move/
/// resize and its body on edit through closures the controller wires to the
/// store. Stays above normal windows so snippets are always reachable (design §6).
public final class NotePanel: NSPanel, NSWindowDelegate {
    public let noteId: String
    private let model: NoteModel
    public var onBodyChange: ((String) -> Void)?
    public var onFrameChange: ((NoteFrame) -> Void)?
    public var onPaste: (() -> Void)?
    public var onDelete: (() -> Void)?

    public init(note: Note) {
        self.noteId = note.id
        self.model = NoteModel(id: note.id, body: note.body)
        let initial = NoteFrame.from(json: note.panelFrame)
            ?? NoteFrame(x: 200, y: 200, w: 240, h: 180)
        super.init(
            contentRect: NSRect(x: initial.x, y: initial.y, width: initial.w, height: initial.h),
            styleMask: [.nonactivatingPanel, .titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        isFloatingPanel = true
        level = .floating
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        delegate = self

        let view = NoteView(
            model: model,
            onBodyChange: { [weak self] in self?.onBodyChange?($0) },
            onPaste: { [weak self] in self?.onPaste?() },
            onDelete: { [weak self] in self?.onDelete?() }
        )
        contentView = NSHostingView(rootView: view)
    }

    public func show() { orderFrontRegardless() }

    private func reportFrame() {
        let f = frame
        onFrameChange?(NoteFrame(x: f.origin.x, y: f.origin.y, w: f.size.width, h: f.size.height))
    }

    public func windowDidMove(_ notification: Notification) { reportFrame() }
    public func windowDidResize(_ notification: Notification) { reportFrame() }

    // Closing the panel deletes the note (a note has no "hidden" state).
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        onDelete?()
        return false        // controller tears the panel down after the store delete
    }

    public override var canBecomeKey: Bool { true }
}
