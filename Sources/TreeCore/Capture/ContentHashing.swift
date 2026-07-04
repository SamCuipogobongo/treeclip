import Foundation
import CryptoKit

/// Content hash for dedup (design §3.5 / Store dedup). SHA-256 over the kept
/// representations, order-independent (sorted by UTI) so the same clipboard
/// content always hashes identically regardless of enumeration order.
///
/// CryptoKit is a system crypto framework (not AppKit), so this stays in the
/// UI-free TreeCore.
public enum ContentHashing {
    public static func hash(_ parts: [(uti: String, bytes: Data)]) -> String {
        var hasher = SHA256()
        for part in parts.sorted(by: { $0.uti < $1.uti }) {
            hasher.update(data: Data(part.uti.utf8))
            hasher.update(data: Data([0]))          // delimiter
            hasher.update(data: part.bytes)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
