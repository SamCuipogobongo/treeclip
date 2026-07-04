import Foundation
import GRDB

// Capture-side input to the store. Deliberately decoupled from NSPasteboard so
// TreeCore stays UI/AppKit-free and the ingest logic is unit-testable with
// plain bytes. The Capture subsystem (M2) produces these.

/// One pasteboard representation to persist.
public struct Representation: Sendable {
    public var uti: String
    public var bytes: Data
    public var isImage: Bool
    public init(uti: String, bytes: Data, isImage: Bool) {
        self.uti = uti; self.bytes = bytes; self.isImage = isImage
    }
}

/// A captured clipboard entry ready to persist.
public struct CapturedItem: Sendable {
    public var kind: String
    public var title: String
    public var contentHash: String
    public var sourceApp: String?
    public var representations: [Representation]
    public var thumbnail: (data: Data, w: Int, h: Int)?
    public var ocrText: String?

    public init(
        kind: String, title: String, contentHash: String, sourceApp: String? = nil,
        representations: [Representation],
        thumbnail: (data: Data, w: Int, h: Int)? = nil, ocrText: String? = nil
    ) {
        self.kind = kind; self.title = title; self.contentHash = contentHash
        self.sourceApp = sourceApp; self.representations = representations
        self.thumbnail = thumbnail; self.ocrText = ocrText
    }
}

extension Store {
    /// Persist a captured item, or bump an existing live duplicate.
    ///
    /// Threshold routing (design §3.1): a representation is inlined only when it
    /// is not an image AND ≤ `inlineMaxBytes`; otherwise its bytes are offloaded
    /// to `payloads/` and the row keeps a `filePath`. Offloaded files are
    /// written *before* the DB transaction so a failed insert leaves only an
    /// orphan file (reclaimed by the orphan scan) rather than a dangling row.
    ///
    /// - Returns: the item id (existing id on dedup hit).
    @discardableResult
    public func ingest(_ captured: CapturedItem, nowMillis: Int64) throws -> String {
        // Dedup: a live item with the same content hash just gets bumped.
        if let existingId = try pool.write({ db -> String? in
            guard var existing = try Item
                .filter(Column("contentHash") == captured.contentHash && Column("deletedAt") == nil)
                .fetchOne(db)
            else { return nil }
            existing.lastPastedAt = nowMillis
            existing.pasteCount += 1
            existing.updatedAt = nowMillis
            try existing.update(db)
            return existing.id
        }) {
            return existingId
        }

        let id = ID.generateV7(nowMillis: nowMillis)

        // Route + offload (outside the transaction).
        var rows: [ContentRow] = []
        for rep in captured.representations {
            let byteCount = Int64(rep.bytes.count)
            if rep.isImage || rep.bytes.count > StorageThresholds.inlineMaxBytes {
                let relPath = try writePayload(itemId: id, uti: rep.uti, data: rep.bytes)
                rows.append(ContentRow(itemId: id, uti: rep.uti, data: nil, filePath: relPath, bytes: byteCount))
            } else {
                rows.append(ContentRow(itemId: id, uti: rep.uti, data: rep.bytes, filePath: nil, bytes: byteCount))
            }
        }

        try pool.write { db in
            var item = Item(
                id: id, kind: captured.kind, title: captured.title,
                contentHash: captured.contentHash, sourceApp: captured.sourceApp,
                firstCopiedAt: nowMillis, lastPastedAt: nowMillis,
                pasteCount: 1, pinned: false, deletedAt: nil, updatedAt: nowMillis
            )
            try item.insert(db)
            for var row in rows { try row.insert(db) }
            if let t = captured.thumbnail {
                var thumb = Thumb(itemId: id, data: t.data, w: t.w, h: t.h)
                try thumb.insert(db)
            }
            try db.execute(
                sql: "INSERT INTO item_fts(item_id, title, ocr_text) VALUES (?, ?, ?)",
                arguments: [id, captured.title, captured.ocrText ?? ""]
            )
            // Flycut discipline: trim over-cap history synchronously, same txn.
            try CapEnforcer.enforceCountCap(db, maxItems: config.maxItems, nowMillis: nowMillis)
        }
        return id
    }

    /// Write an offloaded payload under `payloads/<itemId>/<sanitized-uti>` and
    /// return the path relative to `payloadsDirectory`.
    func writePayload(itemId: String, uti: String, data: Data) throws -> String {
        let safeUTI = uti.replacingOccurrences(of: "/", with: "_")
        let relPath = "\(itemId)/\(safeUTI)"
        let fileURL = location.payloadsDirectory.appendingPathComponent(relPath)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
        return relPath
    }
}
