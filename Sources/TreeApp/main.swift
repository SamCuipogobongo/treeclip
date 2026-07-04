import AppKit
import SwiftUI
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
    private var hotKeyMonitor: Any?
    private let writer = ClipboardWriter()

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            store = try Store(location: try .standard())
        } catch {
            NSApp.presentError(error); NSApp.terminate(nil); return
        }

        driver = CaptureDriver(store: store)
        driver.start()

        let model = PaletteViewModel(store: store)
        panel = PalettePanel(model: model)
        panel.onCommit = { [weak self] row in self?.commit(row) }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "tree", accessibilityDescription: "treeclip")
        statusItem.button?.action = #selector(togglePalette)
        statusItem.button?.target = self

        // ⌘⇧V summon. Global monitor is non-consuming (a v1 tradeoff; a consuming
        // hotkey is an M7 refinement — design §4 flags the Carbon question).
        hotKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command, .shift],
               event.charactersIgnoringModifiers?.lowercased() == "v" {
                Task { @MainActor in self?.panel.toggle() }
            }
        }

        // Verification-only: auto-summon the palette so it can be screenshotted
        // headlessly. Guarded by an env var; a no-op in normal use.
        if ProcessInfo.processInfo.environment["TREE_AUTO_PRESENT"] != nil {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(5))
                await self.panel.present()
            }
        }
    }

    @objc private func togglePalette() { panel.toggle() }

    private func commit(_ row: ListRow) {
        let store = self.store!
        let writer = self.writer
        let panel = self.panel!
        Task { @MainActor in
            if let contents = try? await store.loadContent(itemId: row.id) {
                writer.restore(contents)
            }
            panel.orderOut(nil)
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)          // menu bar only, no Dock icon
let controller = AppController()
app.delegate = controller
app.run()
