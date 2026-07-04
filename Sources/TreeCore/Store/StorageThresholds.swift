import Foundation

/// Single source of truth for the two *orthogonal* storage thresholds.
///
/// These are the crux of treeclip's "flat memory" promise; both must hold, and
/// they answer different questions. See design.md §3.1 and the research report
/// `blob-threshold-logic.md` (SQLite official crossover ~100KB, lower on the
/// default 4096-byte page; Deck's 512KB is an undocumented image-only UI-stall
/// line, deliberately *not* copied here).
public enum StorageThresholds {
    /// **Threshold ① — inline vs offload** (where the payload *bytes* live).
    /// Payload ≤ this stays inline in `content.data`; larger payloads (and all
    /// images, regardless of size) are written to `payloads/` and the row keeps
    /// only a `file_path`. 64KB sits just left of SQLite's crossover so the
    /// ~99% of clipboard items that are tiny text get "inline is faster", while
    /// rare large blocks offload and never squat in the page cache.
    public static let inlineMaxBytes = 64 * 1024

    /// **Threshold ② — list projection** (whether a list query *materializes*
    /// the blob). Orthogonal to ①: even for an inlined payload, list queries
    /// project the `data` column to empty (`X''`) past this size so scrolling
    /// never pulls bytes into memory. This is what actually keeps list render
    /// fast; ① keeps the DB and cache lean.
    public static let listProjectionMaxBytes = 32 * 1024

    /// Max thumbnail byte budget (pre-generated at ingest, inlined in `thumb`).
    /// The list only ever decodes this, never the original image.
    public static let thumbnailMaxBytes = 50 * 1024
}
