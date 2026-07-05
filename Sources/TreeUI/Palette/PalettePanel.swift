import AppKit
import SwiftUI
import TreeCore

/// Borderless, non-activating floating panel that hosts the palette — the same
/// FloatingPanel pattern Maccy 2.x uses (design §2, organ transplant). It can
/// key without stealing focus from the frontmost app, so paste targets the app
/// you were in, not the panel.
public final class PalettePanel: NSPanel {
    private let model: PaletteViewModel
    public var onCommit: ((ListRow, CommitIntent) -> Void)?
    public var onPromote: ((ListRow) -> Void)?
    public var onDelete: ((ListRow) -> Void)?

    public init(model: PaletteViewModel) {
        self.model = model
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        isFloatingPanel = true
        level = .floating
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        let root = PaletteView(
            model: model,
            onCommit: { [weak self] row, intent in self?.onCommit?(row, intent) },
            onEscape: { [weak self] in self?.orderOut(nil) },
            onPromote: { [weak self] row in self?.orderOut(nil); self?.onPromote?(row) },
            onDelete: { [weak self] row in self?.onDelete?(row) }
        )
        contentView = NSHostingView(rootView: root)
    }

    /// Summon: reload from the store, center on the active screen, key the panel.
    public func present() async {
        await model.reload()
        centerOnActiveScreen()
        makeKeyAndOrderFront(nil)
    }

    public func toggle() {
        if isVisible { orderOut(nil) } else { Task { await present() } }
    }

    /// Refresh the list in place (e.g. after deleting an item) without moving
    /// or re-keying the panel.
    public func reloadList() async { await model.reload() }

    private func centerOnActiveScreen() {
        guard let screen = NSScreen.main else { center(); return }
        let visible = screen.visibleFrame
        let size = frame.size
        setFrameOrigin(NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2 + visible.height * 0.1   // slightly above center
        ))
    }

    // Borderless/nonactivating panels must opt in to become key.
    public override var canBecomeKey: Bool { true }
}
