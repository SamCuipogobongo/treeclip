import Foundation

/// A raw pasteboard reading, produced by a `PasteboardSource`. Adapter-neutral
/// so the coordinator's decision logic is testable without a real pasteboard.
public struct RawSnapshot: Sendable {
    public var changeCount: Int
    public var representations: [Representation]
    public var flags: CaptureFlags
    public var sourceApp: String?
    public init(changeCount: Int, representations: [Representation],
                flags: CaptureFlags = [], sourceApp: String? = nil) {
        self.changeCount = changeCount; self.representations = representations
        self.flags = flags; self.sourceApp = sourceApp
    }
}

/// Abstracts the system clipboard so the capture loop is testable with a fake.
public protocol PasteboardSource: Sendable {
    var changeCount: Int { get }
    func snapshot() -> RawSnapshot?
}

/// Turns a raw pasteboard reading into a persistable `CapturedItem` (or nil to
/// ignore), applying the full pipeline: filter → plan → normalize → hash. Pure
/// given a snapshot (no I/O beyond in-memory image transcoding), so CI exercises
/// the whole thing including ImageIO.
public struct CaptureCoordinator: Sendable {
    public var filterConfig: FilterConfig
    public var imageProcessor: ImageProcessor

    public init(filterConfig: FilterConfig = FilterConfig(), imageProcessor: ImageProcessor = ImageProcessor()) {
        self.filterConfig = filterConfig
        self.imageProcessor = imageProcessor
    }

    public func process(_ snapshot: RawSnapshot) -> CapturedItem? {
        let totalBytes = snapshot.representations.reduce(0) { $0 + $1.bytes.count }
        let presentUTIs = Set(snapshot.representations.map(\.uti))
        let filterText = snapshot.representations
            .first { $0.uti == "public.utf8-plain-text" }
            .map { String(decoding: $0.bytes, as: UTF8.self) }
        guard case .capture = FilterChain.decide(
            flags: snapshot.flags, sourceApp: snapshot.sourceApp,
            presentUTIs: presentUTIs, text: filterText,
            totalBytes: totalBytes, config: filterConfig
        ) else { return nil }

        let plan = RepresentationPlanner.plan(snapshot.representations.map {
            RawRepresentation(uti: $0.uti, byteCount: $0.bytes.count, isImage: $0.isImage)
        })

        if plan.kind == "image", let srcUTI = plan.canonicalImageUTI,
           let srcRep = snapshot.representations.first(where: { $0.uti == srcUTI }) {
            guard let img = imageProcessor.process(imageData: srcRep.bytes) else { return nil }
            let hash = ContentHashing.hash([(img.uti, img.canonicalBytes)])
            return CapturedItem(
                kind: "image", title: "Image \(img.sourceW)×\(img.sourceH)", contentHash: hash,
                sourceApp: snapshot.sourceApp,
                representations: [Representation(uti: img.uti, bytes: img.canonicalBytes, isImage: true)],
                thumbnail: (data: img.thumbnailBytes, w: img.thumbW, h: img.thumbH),
                ocrText: nil
            )
        }

        let kept = snapshot.representations.filter { plan.keptUTIs.contains($0.uti) }
        guard !kept.isEmpty else { return nil }
        let hash = ContentHashing.hash(kept.map { (uti: $0.uti, bytes: $0.bytes) })
        let plainText = kept.first(where: { $0.uti == "public.utf8-plain-text" })
            .map { String(decoding: $0.bytes, as: UTF8.self) } ?? ""
        let title = String(plainText.prefix(10_000))
        return CapturedItem(
            kind: plan.kind, title: title, contentHash: hash, sourceApp: snapshot.sourceApp,
            representations: kept, thumbnail: nil, ocrText: nil
        )
    }
}
