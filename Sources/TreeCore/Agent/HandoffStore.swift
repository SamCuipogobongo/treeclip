import Foundation

/// Writes payloads to a handoff directory and hands back a file URL to paste as
/// `@path` into an agent (design §5). Foundation-only, so it's unit-tested in CI.
/// Old handoff files are reclaimed on a TTL — they're transient bridges, not
/// history (which the store already owns).
public struct HandoffStore: Sendable {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }

    /// Write bytes to `<millis>.<ext>` and return the file URL.
    public func write(bytes: Data, ext: String, nowMillis: Int64) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(nowMillis).\(ext)")
        try bytes.write(to: url)
        return url
    }

    /// Delete handoff files older than the TTL. Returns how many were removed.
    @discardableResult
    public func reclaim(nowMillis: Int64, maxAgeMillis: Int64 = 7 * 86_400_000) -> Int {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return 0 }
        var removed = 0
        for url in entries {
            // Skip only names we can't parse; a stamp of 0 is valid (very old).
            guard let stamp = Int64(url.deletingPathExtension().lastPathComponent) else { continue }
            if nowMillis - stamp > maxAgeMillis {
                try? fm.removeItem(at: url)
                removed += 1
            }
        }
        return removed
    }
}
