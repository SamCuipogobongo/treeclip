import Foundation

/// Window geometry for a floating note, persisted as the note's opaque
/// `panelFrame` JSON. Kept in TreeCore (plain data, no AppKit) so the encode/
/// decode round-trip is unit-tested; the UI layer maps it to/from NSRect.
public struct NoteFrame: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double

    public init(x: Double, y: Double, w: Double, h: Double) {
        self.x = x; self.y = y; self.w = w; self.h = h
    }

    public func jsonString() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    public static func from(json: String?) -> NoteFrame? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(NoteFrame.self, from: data)
    }
}
