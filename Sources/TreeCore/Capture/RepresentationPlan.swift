import Foundation

/// A representation available on the pasteboard (adapter-supplied, no bytes yet
/// — just what's offered and how big).
public struct RawRepresentation: Sendable, Equatable {
    public var uti: String
    public var byteCount: Int
    public var isImage: Bool
    public init(uti: String, byteCount: Int, isImage: Bool) {
        self.uti = uti; self.byteCount = byteCount; self.isImage = isImage
    }
}

/// The decision of what to keep and how to classify a snapshot — the reverse of
/// Maccy's "store every format as-is" (design §3.5). For images we keep exactly
/// one source representation to transcode to a single canonical file; for text
/// we keep plain text plus rich text if offered.
public struct RepresentationPlan: Sendable, Equatable {
    public var kind: String
    public var keptUTIs: [String]
    /// Which image UTI to decode/transcode from (nil for non-image).
    public var canonicalImageUTI: String?
}

public enum RepresentationPlanner {
    // Preference order when several image encodings are offered. PNG first
    // (lossless, common for screenshots), then TIFF (large, last resort).
    private static let imagePreference = ["public.png", "public.heic", "public.jpeg", "public.tiff"]

    public static func plan(_ reps: [RawRepresentation]) -> RepresentationPlan {
        let images = reps.filter(\.isImage)
        if !images.isEmpty {
            let canonical = imagePreference.first(where: { uti in images.contains { $0.uti == uti } })
                ?? images[0].uti
            return RepresentationPlan(kind: "image", keptUTIs: [canonical], canonicalImageUTI: canonical)
        }

        // Text-ish: keep plain text, plus rtf/html for fidelity if present.
        let plain = "public.utf8-plain-text"
        if reps.contains(where: { $0.uti == plain }) {
            var kept = [plain]
            for rich in ["public.rtf", "public.html"] where reps.contains(where: { $0.uti == rich }) {
                kept.append(rich)
            }
            return RepresentationPlan(kind: "text", keptUTIs: kept, canonicalImageUTI: nil)
        }

        // Files or anything else: keep everything offered, classify by first uti.
        let kind = reps.first?.uti.hasPrefix("public.file") == true ? "file" : (reps.first?.uti ?? "unknown")
        return RepresentationPlan(kind: kind, keptUTIs: reps.map(\.uti), canonicalImageUTI: nil)
    }
}
