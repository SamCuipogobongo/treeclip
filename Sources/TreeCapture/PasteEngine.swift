import AppKit
import CoreGraphics
import TreeCore

/// Performs a commit: routes it (raw vs `@file` handoff), puts the right thing on
/// the pasteboard, marks ownership so we don't re-capture it, then synthesizes
/// ⌘V into the frontmost app. The routing decision (AgentRouter) and the file
/// write (HandoffStore) are UI-free and unit-tested; this class is the thin
/// AppKit glue around them (design §5, §6.5).
@MainActor
public final class PasteEngine {
    private let store: Store
    private let handoff: HandoffStore
    private let ownership: PasteboardOwnership
    private let config: AgentRouteConfig
    private let writer = ClipboardWriter()
    private let frontAppProvider: @MainActor () -> String?
    private let synthesizesPaste: Bool

    public init(
        store: Store,
        handoff: HandoffStore,
        ownership: PasteboardOwnership,
        config: AgentRouteConfig = .init(),
        frontAppProvider: @escaping @MainActor () -> String? = {
            NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        },
        synthesizesPaste: Bool = true
    ) {
        self.store = store
        self.handoff = handoff
        self.ownership = ownership
        self.config = config
        self.frontAppProvider = frontAppProvider
        self.synthesizesPaste = synthesizesPaste
    }

    /// Restore/handoff the item and paste it. Returns the chosen plan (for logs).
    @discardableResult
    public func paste(row: ListRow, forceRaw: Bool, nowMillis: Int64) async -> PastePlan {
        let contents = (try? await store.loadContent(itemId: row.id)) ?? []
        let text = contents
            .first { $0.uti == "public.utf8-plain-text" }
            .map { String(decoding: $0.bytes, as: UTF8.self) }
        let plan = AgentRouter.plan(
            frontApp: frontAppProvider(), kind: row.kind, text: text,
            forceRaw: forceRaw, config: config
        )

        switch plan {
        case .raw:
            writer.restore(contents)
        case .handoffFile(_, let ext):
            let payload = handoffPayload(kind: row.kind, text: text, contents: contents)
            if let url = try? handoff.write(bytes: payload, ext: ext, nowMillis: nowMillis) {
                writer.restore([(uti: "public.utf8-plain-text", bytes: Data("@\(url.path) ".utf8))])
            } else {
                writer.restore(contents)      // fallback: paste raw if the file write failed
            }
        }

        ownership.markOwned(NSPasteboard.general.changeCount)
        if synthesizesPaste { Self.synthesizeCmdV() }
        return plan
    }

    /// Paste arbitrary text (a note body) through the same routing — short text
    /// pastes inline, long text hands off as `@file` in a terminal.
    @discardableResult
    public func pasteText(_ text: String, forceRaw: Bool, nowMillis: Int64) async -> PastePlan {
        let plan = AgentRouter.plan(
            frontApp: frontAppProvider(), kind: "text", text: text,
            forceRaw: forceRaw, config: config
        )
        switch plan {
        case .raw:
            writer.restore([(uti: "public.utf8-plain-text", bytes: Data(text.utf8))])
        case .handoffFile(_, let ext):
            if let url = try? handoff.write(bytes: Data(text.utf8), ext: ext, nowMillis: nowMillis) {
                writer.restore([(uti: "public.utf8-plain-text", bytes: Data("@\(url.path) ".utf8))])
            } else {
                writer.restore([(uti: "public.utf8-plain-text", bytes: Data(text.utf8))])
            }
        }
        ownership.markOwned(NSPasteboard.general.changeCount)
        if synthesizesPaste { Self.synthesizeCmdV() }
        return plan
    }

    private func handoffPayload(kind: String, text: String?, contents: [(uti: String, bytes: Data)]) -> Data {
        if kind == "image" {
            return contents.first { $0.uti.contains("png") || $0.uti.contains("image") }?.bytes
                ?? contents.first?.bytes ?? Data()
        }
        return Data((text ?? "").utf8)
    }

    /// Synthesize ⌘V into the frontmost app. Best-effort: needs Accessibility
    /// permission; without it the content is still on the clipboard for manual ⌘V.
    static func synthesizeCmdV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 0x09     // kVK_ANSI_V
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
