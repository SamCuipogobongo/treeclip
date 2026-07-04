import AppKit
import TreeCore

/// Writes content back onto the system pasteboard (the restore path). M4 uses
/// this so committing a palette row makes ⌘V paste it; M5's PasteEngine builds
/// on it to synthesize the paste and route the agent @file handoff.
public struct ClipboardWriter: Sendable {
    public init() {}

    public func restore(_ contents: [(uti: String, bytes: Data)]) {
        guard !contents.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        let item = NSPasteboardItem()
        for content in contents {
            item.setData(content.bytes, forType: NSPasteboard.PasteboardType(content.uti))
        }
        pb.writeObjects([item])
    }
}
