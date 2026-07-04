import Foundation

extension Store {
    /// Seed synthetic history for benchmarks/tests (design's M3 fixtures).
    /// Every `imageEveryN`-th item is an image (offloaded original + inline
    /// thumbnail); the rest are short text. Timestamps are strictly increasing
    /// so ordering is deterministic.
    ///
    /// - Note: uses a store configured with a high `maxItems` so the cap does
    ///   not trim the fixture mid-seed.
    public func seedFixture(
        itemCount: Int,
        imageEveryN: Int = 5,
        imageBytes: Int = 400_000,      // ~4K-ish PNG stand-in
        thumbBytes: Int = 4_096,
        baseMillis: Int64
    ) throws {
        for k in 0..<itemCount {
            let ts = baseMillis + Int64(k) * 1_000
            if imageEveryN > 0 && k % imageEveryN == 0 {
                let img = Representation(uti: "public.png", bytes: Data(count: imageBytes), isImage: true)
                try ingest(CapturedItem(
                    kind: "image", title: "image \(k)", contentHash: "img-\(k)",
                    representations: [img],
                    thumbnail: (data: Data(count: thumbBytes), w: 400, h: 300),
                    ocrText: "screenshot \(k)"
                ), nowMillis: ts)
            } else {
                let body = "clip \(k) " + String(repeating: "y", count: 200)
                try ingest(CapturedItem(
                    kind: "text", title: String(body.prefix(80)), contentHash: "txt-\(k)",
                    representations: [Representation(uti: "public.utf8-plain-text",
                                                    bytes: Data(body.utf8), isImage: false)],
                    ocrText: nil
                ), nowMillis: ts)
            }
        }
    }
}
