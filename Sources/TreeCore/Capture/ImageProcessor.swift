import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

/// Result of normalizing a captured image: one canonical PNG for the payload,
/// plus a pre-generated thumbnail (design §3.5). No AppKit — ImageIO/CoreGraphics
/// are headless-safe, so this whole path is CI-testable.
public struct ProcessedImage: Sendable {
    public var uti: String                 // canonical payload UTI (public.png)
    public var canonicalBytes: Data
    public var thumbnailBytes: Data
    public var thumbW: Int
    public var thumbH: Int
    public var sourceW: Int
    public var sourceH: Int
}

public struct ImageProcessor: Sendable {
    public init() {}

    /// Decode arbitrary image bytes, re-encode a single canonical PNG (dropping
    /// the multi-format bloat Maccy kept), and generate a downsampled thumbnail
    /// in one pass. Returns nil if the bytes aren't a decodable image.
    public func process(imageData: Data) -> ProcessedImage? {
        guard let src = CGImageSourceCreateWithData(imageData as CFData, nil),
              let full = CGImageSourceCreateImageAtIndex(src, 0, nil),
              let canonical = Self.encodePNG(full)
        else { return nil }

        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: ThumbnailSizing.maxLongEdge,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let thumbCG = CGImageSourceCreateThumbnailAtIndex(src, 0, thumbOptions as CFDictionary),
              let thumbBytes = Self.encodePNG(thumbCG)
        else { return nil }

        return ProcessedImage(
            uti: "public.png", canonicalBytes: canonical,
            thumbnailBytes: thumbBytes, thumbW: thumbCG.width, thumbH: thumbCG.height,
            sourceW: full.width, sourceH: full.height
        )
    }

    static func encodePNG(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }
}
