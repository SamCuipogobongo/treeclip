import Testing
import Foundation
import CoreGraphics
@testable import TreeCore

@Suite struct CaptureCoordinatorTests {
    /// Build a real PNG at the given size, headless (CoreGraphics only).
    private func makePNG(w: Int, h: Int) -> Data {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        return ImageProcessor.encodePNG(ctx.makeImage()!)!
    }

    @Test func imageSnapshotProducesThumbnailCappedAt400() throws {
        let snap = RawSnapshot(changeCount: 1, representations: [
            Representation(uti: "public.png", bytes: makePNG(w: 1600, h: 1200), isImage: true)
        ])
        let item = try #require(CaptureCoordinator().process(snap))
        #expect(item.kind == "image")
        #expect(item.representations.count == 1)
        #expect(item.representations[0].isImage)
        let thumb = try #require(item.thumbnail)
        #expect(max(thumb.w, thumb.h) <= 400)          // downsampled
    }

    @Test func multiFormatImageKeepsSingleCanonicalPNG() throws {
        let png = makePNG(w: 100, h: 100)
        let snap = RawSnapshot(changeCount: 1, representations: [
            Representation(uti: "public.tiff", bytes: png, isImage: true),
            Representation(uti: "public.png", bytes: png, isImage: true),
        ])
        let item = try #require(CaptureCoordinator().process(snap))
        #expect(item.representations.count == 1)        // not both formats
        #expect(item.representations[0].uti == "public.png")
    }

    @Test func textSnapshotProducesTextItem() throws {
        let snap = RawSnapshot(changeCount: 1, representations: [
            Representation(uti: "public.utf8-plain-text", bytes: Data("hello agent".utf8), isImage: false)
        ], sourceApp: "com.apple.Terminal")
        let item = try #require(CaptureCoordinator().process(snap))
        #expect(item.kind == "text")
        #expect(item.title == "hello agent")
        #expect(item.sourceApp == "com.apple.Terminal")
    }

    @Test func concealedSnapshotIsDropped() {
        let snap = RawSnapshot(changeCount: 1, representations: [
            Representation(uti: "public.utf8-plain-text", bytes: Data("hunter2".utf8), isImage: false)
        ], flags: .concealed)
        #expect(CaptureCoordinator().process(snap) == nil)
    }

    @Test func endToEndImageIntoStore() async throws {
        let store = try Store.temporary()
        let snap = RawSnapshot(changeCount: 1, representations: [
            Representation(uti: "public.png", bytes: makePNG(w: 800, h: 600), isImage: true)
        ])
        let item = try #require(CaptureCoordinator().process(snap))
        let id = try await store.ingest(item, nowMillis: 1_000)

        let rows = try await store.contentRows(itemId: id)
        #expect(rows[0].filePath != nil)                // image offloaded
        #expect(try await store.thumb(itemId: id) != nil)
        let list = try await store.listItems(limit: 10)
        #expect(list.count == 1)
        #expect(list[0].thumb != nil)                   // list shows thumb, never payload
    }
}
