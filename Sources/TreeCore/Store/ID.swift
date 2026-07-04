import Foundation

/// UUIDv7 generator: 48-bit millisecond timestamp + 74 random bits, formatted
/// as a standard UUID string. Time-ordered (so ids sort by creation and give
/// good SQLite index locality) and globally unique (sync-ready, roadmap).
enum ID {
    static func generateV7(nowMillis: Int64) -> String {
        var b = [UInt8](repeating: 0, count: 16)
        let t = UInt64(bitPattern: nowMillis) & 0xFFFF_FFFF_FFFF
        b[0] = UInt8((t >> 40) & 0xFF)
        b[1] = UInt8((t >> 32) & 0xFF)
        b[2] = UInt8((t >> 24) & 0xFF)
        b[3] = UInt8((t >> 16) & 0xFF)
        b[4] = UInt8((t >> 8) & 0xFF)
        b[5] = UInt8(t & 0xFF)
        for i in 6..<16 { b[i] = UInt8.random(in: 0...255) }
        b[6] = (b[6] & 0x0F) | 0x70   // version 7
        b[8] = (b[8] & 0x3F) | 0x80   // RFC 4122 variant

        func hex(_ r: Range<Int>) -> String { r.map { String(format: "%02x", b[$0]) }.joined() }
        return "\(hex(0..<4))-\(hex(4..<6))-\(hex(6..<8))-\(hex(8..<10))-\(hex(10..<16))"
    }
}
