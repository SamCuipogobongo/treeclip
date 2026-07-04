import SwiftUI

/// One floating note: a small translucent card with an editable body and a
/// header for paste/delete. Kept dumb — all persistence/paste is delegated up
/// to the panel via closures.
@MainActor
@Observable
public final class NoteModel {
    public let id: String
    public var body: String
    public init(id: String, body: String) { self.id = id; self.body = body }
}

public struct NoteView: View {
    @Bindable var model: NoteModel
    var onBodyChange: (String) -> Void
    var onPaste: () -> Void
    var onDelete: () -> Void

    public init(model: NoteModel,
                onBodyChange: @escaping (String) -> Void,
                onPaste: @escaping () -> Void,
                onDelete: @escaping () -> Void) {
        self.model = model
        self.onBodyChange = onBodyChange
        self.onPaste = onPaste
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            TextEditor(text: $model.body)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .padding(6)
                .onChange(of: model.body) { _, new in onBodyChange(new) }
        }
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Button(action: onPaste) { Image(systemName: "arrow.up.doc.on.clipboard") }
                .help("Paste into the frontmost app")
            Spacer()
            Button(action: onDelete) { Image(systemName: "trash") }
                .help("Delete note")
        }
        .buttonStyle(.plain)
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(.quaternary.opacity(0.5))
    }
}
