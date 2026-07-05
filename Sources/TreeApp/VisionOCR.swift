import Foundation
import Vision
import ImageIO
import CoreGraphics

// Vision-backed text recognizer, injected into the capture pipeline as a
// `TextRecognizer`. This is the ONLY file that imports Vision — keeping it in
// the (untested) executable means CI's test binaries never link Vision, which
// avoids the headless-runner dyld-load hang (2026-07-05).
enum VisionOCR {
    static func recognize(_ imageData: Data) -> String? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try? VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        let lines = request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }
}
