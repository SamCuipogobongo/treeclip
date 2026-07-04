import AppKit
import Carbon.HIToolbox

/// Global hotkeys via Carbon `RegisterEventHotKey`. Chosen over an NSEvent global
/// monitor because that monitor (a) needs Accessibility permission to see other
/// apps' key events — so it silently does nothing until granted — and (b) is
/// non-consuming, leaking the keystroke to the frontmost app. RegisterEventHotKey
/// needs no permission and consumes the key. (design §4 flagged avoiding Carbon,
/// but it's the only dependency-free API that is both permission-free and
/// consuming; the pure-Swift alternatives all wrap it anyway.)
public final class HotKeyCenter {
    nonisolated(unsafe) public static let shared = HotKeyCenter()

    // All access is on the main thread (register from setup; handle from the
    // Carbon handler which fires on the main run loop) — hence unsafe-nonisolated.
    nonisolated(unsafe) private var handlers: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1
    private var installed = false

    private init() {}

    /// Register a global hotkey. `modifiers` are Carbon masks (cmdKey/optionKey/…).
    @MainActor
    public func register(keyCode: UInt32, modifiers: UInt32, action: @escaping @MainActor () -> Void) {
        installHandlerIfNeeded()
        let id = nextID
        nextID += 1
        handlers[id] = { MainActor.assumeIsolated { action() } }
        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: 0x5452_4545 /* 'TREE' */, id: id)
        RegisterEventHotKey(keyCode, modifiers, hkID, GetApplicationEventTarget(), 0, &ref)
    }

    private func installHandlerIfNeeded() {
        guard !installed else { return }
        installed = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), hotKeyEventCallback, 1, &spec, nil, nil)
    }

    fileprivate func handle(id: UInt32) { handlers[id]?() }
}

/// Top-level (non-capturing) so it converts to a C function pointer. Carbon
/// dispatches hotkey events on the main run loop.
private func hotKeyEventCallback(
    _ next: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    var hkID = EventHotKeyID()
    GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                      nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
    let id = hkID.id
    DispatchQueue.main.async { HotKeyCenter.shared.handle(id: id) }
    return noErr
}
