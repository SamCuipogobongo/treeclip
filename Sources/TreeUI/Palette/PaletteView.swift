import SwiftUI
import AppKit
import TreeCore

/// The palette surface: a search field over a keyboard-navigable history list.
/// Rows render from `ListRow` (metadata + thumbnail) only — never the payload,
/// preserving the projection discipline all the way to the pixels.
public struct PaletteView: View {
    @Bindable var model: PaletteViewModel
    /// Called when the user commits a row (Enter / click). The host performs the
    /// actual restore/paste (M5) and closes the panel.
    var onCommit: (ListRow) -> Void
    var onEscape: () -> Void
    var onPromote: (ListRow) -> Void

    @FocusState private var searchFocused: Bool

    public init(model: PaletteViewModel,
                onCommit: @escaping (ListRow) -> Void,
                onEscape: @escaping () -> Void,
                onPromote: @escaping (ListRow) -> Void = { _ in }) {
        self.model = model
        self.onCommit = onCommit
        self.onEscape = onEscape
        self.onPromote = onPromote
    }

    public var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            list
        }
        .frame(width: 640, height: 420)
        .background(.ultraThinMaterial)
        .onAppear { searchFocused = true }
    }

    private var searchField: some View {
        TextField("Search clipboard…", text: $model.query)
            .textFieldStyle(.plain)
            .font(.system(size: 15))
            .padding(12)
            .focused($searchFocused)
            .onChange(of: model.query) { _, _ in Task { await model.reload() } }
            .onKeyPress(.downArrow) { model.moveDown(); return .handled }
            .onKeyPress(.upArrow) { model.moveUp(); return .handled }
            .onKeyPress(.return) {
                if let row = model.selectedRow { onCommit(row) }
                return .handled
            }
            .onKeyPress(.escape) { onEscape(); return .handled }
            .background(promoteShortcut)                      // ⌘N: promote selection to a note
    }

    // A hidden ⌘N shortcut. Command-modified shortcuts fire even while the
    // search field is focused, and don't interfere with typing a plain "n".
    private var promoteShortcut: some View {
        Button("") { if let row = model.selectedRow { onPromote(row) } }
            .keyboardShortcut("n", modifiers: .command)
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, row in
                        PaletteRowView(row: row, selected: index == model.selectedIndex)
                            .id(row.id)
                            .contentShape(Rectangle())
                            .onTapGesture { model.select(index); onCommit(row) }
                    }
                }
            }
            .onChange(of: model.selectedIndex) { _, new in
                if model.rows.indices.contains(new) {
                    withAnimation(.easeOut(duration: 0.08)) { proxy.scrollTo(model.rows[new].id) }
                }
            }
        }
    }
}

struct PaletteRowView: View {
    let row: ListRow
    let selected: Bool

    var body: some View {
        HStack(spacing: 10) {
            thumbnail
            Text(row.title.isEmpty ? "(empty)" : row.title)
                .lineLimit(1)
                .font(.system(size: 13))
            Spacer()
            if row.pinned { Image(systemName: "pin.fill").font(.caption2).foregroundStyle(.secondary) }
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(selected ? Color.accentColor.opacity(0.22) : .clear)
    }

    @ViewBuilder private var thumbnail: some View {
        if let data = row.thumb, let image = NSImage(data: data) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28).clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            Image(systemName: icon(for: row.kind)).frame(width: 28, height: 28)
                .foregroundStyle(.secondary)
        }
    }

    private func icon(for kind: String) -> String {
        switch kind {
        case "image": "photo"
        case "file": "doc"
        default: "text.alignleft"
        }
    }
}
