import Testing
import Foundation
import CoreGraphics
@testable import TreeCore

// Verifies the OCR *plumbing* (injected recognizer → CapturedItem.ocrText →
// item_fts) with a fake recognizer, so it runs on CI without linking Vision.
// The real Vision recognizer lives in TreeApp and is exercised on-device.
@Suite struct OCRPlumbingTests {
    private func solidPNG() -> Data {
        let ctx = CGContext(data: nil, width: 40, height: 40, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        return ImageProcessor.encodePNG(ctx.makeImage()!)!
    }

    @Test func injectedRecognizerMakesImageSearchable() async throws {
        let recognizer: TextRecognizer = { _ in "INVOICE total 42" }
        let coordinator = CaptureCoordinator(imageProcessor: ImageProcessor(recognizer: recognizer))
        let snap = RawSnapshot(changeCount: 1, representations: [
            Representation(uti: "public.png", bytes: solidPNG(), isImage: true)
        ])
        let item = try #require(coordinator.process(snap))
        #expect(item.ocrText == "INVOICE total 42")

        let store = try Store.temporary()
        _ = try await store.ingest(item, nowMillis: 1_000)
        let hits = try await store.search("invoice", limit: 10)
        #expect(hits.count == 1)
        #expect(hits[0].kind == "image")
    }

    @Test func noRecognizerLeavesOCRNil() async throws {
        let coordinator = CaptureCoordinator(imageProcessor: ImageProcessor())   // no recognizer
        let snap = RawSnapshot(changeCount: 1, representations: [
            Representation(uti: "public.png", bytes: solidPNG(), isImage: true)
        ])
        let item = try #require(coordinator.process(snap))
        #expect(item.ocrText == nil)
    }
}
