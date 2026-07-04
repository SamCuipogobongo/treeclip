import Foundation
import GRDB

/// The storage engine. Wraps a GRDB `DatabasePool` (WAL + a pool of readers
/// concurrent with a single serialized writer — design.md §3.3's read/write
/// separation, for free). Owns schema migration; higher-level ingest/query/GC
/// build on top.
///
/// An `actor` so the writer path is serialized at the Swift level too; GRDB's
/// own writer serialization is the DB-level guarantee, this is the app-level one.
public actor Store {
    /// Where the SQLite file and offloaded payloads live.
    public struct Location: Sendable {
        public var databasePath: String
        public var payloadsDirectory: URL
        public init(databasePath: String, payloadsDirectory: URL) {
            self.databasePath = databasePath
            self.payloadsDirectory = payloadsDirectory
        }

        /// Default: `~/Library/Application Support/treeclip/`.
        public static func standard(fileManager: FileManager = .default) throws -> Location {
            let base = try fileManager.url(
                for: .applicationSupportDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true
            ).appendingPathComponent("treeclip", isDirectory: true)
            return Location(
                databasePath: base.appendingPathComponent("Store.sqlite").path,
                payloadsDirectory: base.appendingPathComponent("payloads", isDirectory: true)
            )
        }
    }

    /// Retention policy. Both axes exempt pinned items (design §3.4).
    public struct Config: Sendable {
        /// Count cap on live non-pinned items; the oldest beyond this are
        /// tombstoned synchronously on the write path (Flycut discipline).
        public var maxItems: Int
        /// Age cap in days on `lastPastedAt` (not creation); nil disables expiry.
        public var maxAgeDays: Int?
        public init(maxItems: Int = 1000, maxAgeDays: Int? = 90) {
            self.maxItems = maxItems
            self.maxAgeDays = maxAgeDays
        }
    }

    let pool: DatabasePool
    let location: Location
    let config: Config

    public init(location: Location, config: Config = Config()) throws {
        self.location = location
        self.config = config

        let fm = FileManager.default
        try fm.createDirectory(
            at: URL(fileURLWithPath: location.databasePath).deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fm.createDirectory(at: location.payloadsDirectory, withIntermediateDirectories: true)

        var config = Configuration()
        config.foreignKeysEnabled = true          // enforce content/thumb cascades
        self.pool = try DatabasePool(path: location.databasePath, configuration: config)

        try Schema.migrator.migrate(pool)
    }

    /// Test/ephemeral store backed by a temp directory.
    public static func temporary(config: Config = Config()) throws -> Store {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("treeclip-\(UUID().uuidString)", isDirectory: true)
        return try Store(location: Location(
            databasePath: dir.appendingPathComponent("Store.sqlite").path,
            payloadsDirectory: dir.appendingPathComponent("payloads", isDirectory: true)
        ), config: config)
    }

    /// Live (non-tombstoned) item count. Small helper used by tests and caps.
    public func liveItemCount() throws -> Int {
        try pool.read { db in
            try Item.filter(Column("deletedAt") == nil).fetchCount(db)
        }
    }
}
