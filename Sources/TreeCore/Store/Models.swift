import Foundation
import GRDB

// Record types mirror design.md §3.2. Every id is a UUIDv7-style string and
// every row carries `updated_at` + soft-delete `deleted_at` so the schema is
// sync-ready from day 1 (roadmap: cloud sync) without doing sync in v1.

/// A single clipboard entry (metadata only — payload bytes live in `ContentRow`).
public struct Item: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Sendable {
    public static let databaseTableName = "item"

    public var id: String
    public var kind: String                 // text | image | file | rtf | ...
    public var title: String                // truncated preview (≤10k chars)
    public var contentHash: String          // dedup short-circuit
    public var sourceApp: String?
    public var firstCopiedAt: Int64
    public var lastPastedAt: Int64          // expiry axis uses this, not creation
    public var pasteCount: Int
    public var pinned: Bool
    public var deletedAt: Int64?            // tombstone; GC hard-deletes later
    public var updatedAt: Int64

    public init(
        id: String, kind: String, title: String, contentHash: String,
        sourceApp: String? = nil, firstCopiedAt: Int64, lastPastedAt: Int64,
        pasteCount: Int = 0, pinned: Bool = false, deletedAt: Int64? = nil,
        updatedAt: Int64
    ) {
        self.id = id; self.kind = kind; self.title = title
        self.contentHash = contentHash; self.sourceApp = sourceApp
        self.firstCopiedAt = firstCopiedAt; self.lastPastedAt = lastPastedAt
        self.pasteCount = pasteCount; self.pinned = pinned
        self.deletedAt = deletedAt; self.updatedAt = updatedAt
    }
}

/// One row per pasteboard representation (UTI). Bytes are inline (`data`) XOR
/// on disk (`filePath`) per StorageThresholds.inlineMaxBytes; images always
/// take the `filePath` branch.
public struct ContentRow: Codable, FetchableRecord, MutablePersistableRecord, Sendable {
    public static let databaseTableName = "content"

    public var itemId: String
    public var uti: String                  // public.utf8-plain-text / public.png ...
    public var data: Data?                  // inline (≤64KB), else nil
    public var filePath: String?            // offloaded payload, else nil
    public var bytes: Int64

    public init(itemId: String, uti: String, data: Data?, filePath: String?, bytes: Int64) {
        self.itemId = itemId; self.uti = uti
        self.data = data; self.filePath = filePath; self.bytes = bytes
    }
}

/// Pre-generated thumbnail, inlined. The list view only ever decodes this.
public struct Thumb: Codable, FetchableRecord, MutablePersistableRecord, Sendable {
    public static let databaseTableName = "thumb"

    public var itemId: String
    public var data: Data
    public var w: Int
    public var h: Int

    public init(itemId: String, data: Data, w: Int, h: Int) {
        self.itemId = itemId; self.data = data; self.w = w; self.h = h
    }
}

/// A floating note (snippets surface). May originate from a history item.
public struct Note: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Sendable {
    public static let databaseTableName = "note"

    public var id: String
    public var body: String
    public var panelFrame: String?          // window geometry JSON
    public var originItemId: String?        // provenance if "promoted" from history
    public var sortOrder: Double
    public var createdAt: Int64
    public var updatedAt: Int64
    public var deletedAt: Int64?

    public init(
        id: String, body: String, panelFrame: String? = nil,
        originItemId: String? = nil, sortOrder: Double,
        createdAt: Int64, updatedAt: Int64, deletedAt: Int64? = nil
    ) {
        self.id = id; self.body = body; self.panelFrame = panelFrame
        self.originItemId = originItemId; self.sortOrder = sortOrder
        self.createdAt = createdAt; self.updatedAt = updatedAt; self.deletedAt = deletedAt
    }
}
