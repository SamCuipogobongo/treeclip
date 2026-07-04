import AppKit
import ApplicationServices

/// Gate for synthetic ⌘V. Posting CGEvents into another app requires the process
/// to be trusted for Accessibility; without it `PasteEngine.synthesizeCmdV` is a
/// silent no-op and treeclip falls back to "content is on the clipboard, press
/// ⌘V yourself". This drives the one-time grant so paste is truly automatic.
///
/// Dev note: a `swift run` binary has no bundle identity, so the grant attaches
/// to the launching terminal. The shipped, notarized app (M7) requests its own.
public enum AccessibilityAuthorizer {
    public static var isTrusted: Bool { AXIsProcessTrusted() }

    /// If not yet trusted, present the system prompt that deep-links to
    /// Settings → Privacy & Security → Accessibility. Returns current trust.
    @discardableResult
    public static func requestIfNeeded() -> Bool {
        if isTrusted { return true }
        // Literal value of kAXTrustedCheckOptionPrompt — referencing the global
        // CFString constant directly trips Swift 6 concurrency checking.
        let promptKey = "AXTrustedCheckOptionPrompt"
        return AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }
}
