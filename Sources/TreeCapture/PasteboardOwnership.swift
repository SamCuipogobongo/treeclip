import Foundation

/// Shared token so the capture loop can tell "the clipboard just changed because
/// *we* wrote to it" apart from a real user copy (design §4). PasteEngine writes
/// to the pasteboard then records the resulting changeCount here; CaptureDriver
/// skips that changeCount so our own paste never re-enters history.
@MainActor
public final class PasteboardOwnership {
    private var ownedChangeCount: Int = -1
    public init() {}
    public func markOwned(_ changeCount: Int) { ownedChangeCount = changeCount }
    public func isOwned(_ changeCount: Int) -> Bool { changeCount == ownedChangeCount }
}
