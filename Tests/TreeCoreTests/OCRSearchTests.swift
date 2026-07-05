import Testing
import Foundation
import CoreGraphics
import CoreText
@testable import TreeCore

@Suite struct OCRSearchTests {
    /// Render a word onto a white PNG so Vision has something to read.
    private func pngWithText(_ text: String) -> Data {
        let w = 600, h = 200
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        let font = CTFontCreateWithName("Helvetica" as CFString, 72, nil)
        let attrs = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: CGColor(red: 0, green: 0, blue: 0, alpha: 1),
        ] as CFDictionary
        let attrString = CFAttributedStringCreate(nil, text as CFString, attrs)!
        let line = CTLineCreateWithAttributedString(attrString)
        ctx.textPosition = CGPoint(x: 30, y: 80)
        CTLineDraw(line, ctx)
        return ImageProcessor.encodePNG(ctx.makeImage()!)!
    }

    @Test func imageTextIsRecognizedAndSearchable() async throws {
        let png = pngWithText("KRAKEN")
        let snap = RawSnapshot(changeCount: 1, representations: [
            Representation(uti: "public.png", bytes: png, isImage: true)
        ])
        let item = try #require(CaptureCoordinator().process(snap))
        // OCR ran and found the word.
        #expect(item.ocrText?.uppercased().contains("KRAKEN") == true)

        let store = try Store.temporary()
        _ = try await store.ingest(item, nowMillis: 1_000)
        // The image is findable by its rendered text via FTS.
        let hits = try await store.search("kraken", limit: 10)
        #expect(hits.count == 1)
        #expect(hits[0].kind == "image")
    }
}
