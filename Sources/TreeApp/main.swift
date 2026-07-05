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
    private var paletteModel: PaletteViewModel!
    private let settingsStore = SettingsStore()
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = settingsStore.load()
        LaunchAtLogin.apply(settings.launchAtLogin)

        do {
            store = try Store(location: try .standard(), config: settings.storeConfig)
        } catch {
            NSApp.presentError(error); NSApp.terminate(nil); return
        }

        let ownership = PasteboardOwnership()
        // Inject Vision OCR here (the only Vision link point) so captured images
        // become text-searchable without TreeCore ever linking Vision.
        let coordinator = CaptureCoordinator(
            filterConfig: settings.filterConfig,
            imageProcessor: ImageProcessor(recognizer: VisionOCR.recognize)
        )
        driver = CaptureDriver(store: store, coordinator: coordinator,
                               ownership: ownership, interval: settings.checkInterval)
        driver.start()

        let handoffDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("treeclip/handoff", isDirectory: true)
        pasteEngine = PasteEngine(
            store: store,
            handoff: HandoffStore(directory: handoffDir),
            ownership: ownership,
            config: settings.agentRouteConfig
        )

        notes = NotesController(store: store, pasteEngine: pasteEngine)
        Task { await notes.restore() }

        // Enable truly-automatic paste: synthesizing ⌘V needs Accessibility.
        // This pops the one-time grant prompt; until granted, paste falls back
        // to leaving content on the clipboard for a manual ⌘V.
        AccessibilityAuthorizer.requestIfNeeded()

        paletteModel = PaletteViewModel(store: store)
        panel = PalettePanel(model: paletteModel)
        panel.onCommit = { [weak self] row, intent in self?.commit(row, intent) }
        panel.onPromote = { [weak self] row in
            Task { @MainActor in await self?.notes.promote(itemId: row.id) }
        }
        panel.onDelete = { [weak self] row in self?.deleteItem(row) }
        panel.onTogglePin = { [weak self] row in self?.togglePin(row) }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "tree", accessibilityDescription: "treeclip")
        statusItem.menu = buildMenu()

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

    @objc private func openSettings() {
        let view = SettingsView(initial: settingsStore.load()) { [weak self] new in
            self?.saveSettings(new)
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Tree Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        settingsWindow = window
        NSApp.activate(ignoringOtherApps: true)          // accessory app must foreground to show a window
        window.makeKeyAndOrderFront(nil)
    }

    private func saveSettings(_ new: AppSettings) {
        let old = settingsStore.load()
        settingsStore.save(new)
        if new.launchAtLogin != old.launchAtLogin { LaunchAtLogin.apply(new.launchAtLogin) }
        settingsWindow?.close()
        // Other config (cap, filters, interval, terminal list) is read at launch;
        // it takes effect on next start — communicated in the form's footer.
    }

    @objc private func clearHistory() { performClear(keepPinned: true) }
    @objc private func clearAll() { performClear(keepPinned: false) }
    @objc private func quit() { NSApp.terminate(nil) }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let open = NSMenuItem(title: "Open Tree", action: #selector(togglePalette), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let clear = NSMenuItem(title: "Clear History (keep pinned)", action: #selector(clearHistory), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)
        let clearAllItem = NSMenuItem(title: "Clear All", action: #selector(clearAll), keyEquivalent: "")
        clearAllItem.target = self
        menu.addItem(clearAllItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Tree", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        return menu
    }

    private func performClear(keepPinned: Bool) {
        let store = store!, panel = panel!
        Task { @MainActor in
            try? await store.clear(keepPinned: keepPinned, nowMillis: nowMillis())
            await panel.reloadList()
        }
    }

    private func commit(_ row: ListRow, _ intent: CommitIntent) {
        var options: PasteOptions = []
        // ⇧ (plain) and ⌥ (raw) read live — they don't block the Enter handler.
        // ⌘ is deliberately NOT read here: it's the routing key for ⌘Enter /
        // ⌘1-9, so reading it would mislabel a quick-paste as copy-only.
        let mods = NSEvent.modifierFlags
        if mods.contains(.shift) { options.insert(.plainText) }
        if mods.contains(.option) { options.insert(.forceRaw) }
        if intent == .copyOnly { options.insert(.copyOnly) }
        let engine = pasteEngine!, panel = panel!, now = nowMillis()
        panel.orderOut(nil)                                       // close first so ⌘V targets the prior app
        Task { @MainActor in await engine.paste(row: row, options: options, nowMillis: now) }
    }

    private func deleteItem(_ row: ListRow) {
        let store = store!, panel = panel!
        Task { @MainActor in
            try? await store.softDelete(id: row.id, nowMillis: nowMillis())
            await panel.reloadList()                              // refresh in place, keep palette open
        }
    }

    private func togglePin(_ row: ListRow) {
        let store = store!, panel = panel!
        Task { @MainActor in
            try? await store.setPinned(id: row.id, pinned: !row.pinned, nowMillis: nowMillis())
            await panel.reloadList()
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)          // menu bar only, no Dock icon
let controller = AppController()
app.delegate = controller
app.run()
