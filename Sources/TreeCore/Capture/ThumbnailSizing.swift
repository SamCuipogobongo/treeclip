import Foundation

/// Pure thumbnail sizing. The adapter feeds source dimensions and gets back the
/// target pixel size (long edge capped, aspect preserved). The thumbnail is
/// generated once at ingest and is the only image the list ever decodes (§3.5).
public enum ThumbnailSizing {
    public static let maxLongEdge = 400

    public static func target(width: Int, height: Int, maxLongEdge: Int = maxLongEdge) -> (w: Int, h: Int) {
        guard width > 0, height > 0 else { return (0, 0) }
        let longEdge = max(width, height)
        guard longEdge > maxLongEdge else { return (width, height) }   // don't upscale
        let scale = Double(maxLongEdge) / Double(longEdge)
        return (max(1, Int((Double(width) * scale).rounded())),
                max(1, Int((Double(height) * scale).rounded())))
    }
}
