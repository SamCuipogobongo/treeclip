import AppKit
import SwiftUI
import Carbon.HIToolbox
import TreeCore
import TreeUI
import TreeCapture

// M4 assembly: a menu bar app that captures the clipboard and shows a summonable
// palette. Not the final polish (that's M7), but the first runnable Tree:
//   • menu bar icon → toggle palette
//   • ⌘⇧V global hotkey → toggle palette
//   • Enter/click a row → restore it to the clipboard (⌘V to paste; M5 auto-pastes)
@MainActor
final class AppController: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var store: Store!
    private var driver: CaptureDriver!
    private var panel: PalettePanel!
    private var pasteEngine: PasteEngine!
    private var notes: NotesController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            store = try Store(location: try .standard())
        } catch {
            NSApp.presentError(error); NSApp.terminate(nil); return
        }

        let ownership = PasteboardOwnership()
        driver = CaptureDriver(store: store, ownership: ownership)
        driver.start()

        let handoffDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("treeclip/handoff", isDirectory: true)
        pasteEngine = PasteEngine(
            store: store,
            handoff: HandoffStore(directory: handoffDir),
            ownership: ownership
        )

        notes = NotesController(store: store, pasteEngine: pasteEngine)
        Task { await notes.restore() }

        // Enable truly-automatic paste: synthesizing ⌘V needs Accessibility.
        // This pops the one-time grant prompt; until granted, paste falls back
        // to leaving content on the clipboard for a manual ⌘V.
        AccessibilityAuthorizer.requestIfNeeded()

        let model = PaletteViewModel(store: store)
        panel = PalettePanel(model: model)
        panel.onCommit = { [weak self] row in self?.commit(row) }
        panel.onPromote = { [weak self] row in
            Task { @MainActor in await self?.notes.promote(itemId: row.id) }
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "tree", accessibilityDescription: "treeclip")
        statusItem.button?.action = #selector(togglePalette)
        statusItem.button?.target = self

        // ⌘⇧V summon. Global monitor is non-consuming (a v1 tradeoff; a consuming
        // hotkey is an M7 refinement — design §4 flags the Carbon question).
        // ⌥= summon palette · ⌘⇧N new note. Carbon hotkeys: permission-free and
        // consuming (an NSEvent global monitor needs Accessibility and leaks the
        // key to the frontmost app).
        HotKeyCenter.shared.register(keyCode: UInt32(kVK_ANSI_Equal), modifiers: UInt32(optionKey)) { [weak self] in
            self?.panel.toggle()
        }
        HotKeyCenter.shared.register(keyCode: UInt32(kVK_ANSI_N), modifiers: UInt32(cmdKey | shiftKey)) { [weak self] in
            Task { @MainActor in await self?.notes.newNote() }
        }

    }

    @objc private func togglePalette() { panel.toggle() }

    private func commit(_ row: ListRow) {
        let forceRaw = NSEvent.modifierFlags.contains(.option)   // ⌥+Enter = paste raw
        let engine = self.pasteEngine!
        let panel = self.panel!
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        panel.orderOut(nil)                                       // close first so ⌘V targets the prior app
        Task { @MainActor in
            await engine.paste(row: row, forceRaw: forceRaw, nowMillis: now)
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)          // menu bar only, no Dock icon
let controller = AppController()
app.delegate = controller
app.run()
