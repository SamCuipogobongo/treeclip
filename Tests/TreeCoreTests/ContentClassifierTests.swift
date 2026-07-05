import Testing
import Foundation
@testable import TreeCore

@Suite struct ContentClassifierTests {
    private func cat(_ text: String, kind: String = "text") -> ContentCategory {
        ContentClassifier.classify(kind: kind, text: text)
    }

    @Test func detectsLinks() {
        #expect(cat("https://github.com/SamCuipogobongo/treeclip") == .link)
        #expect(cat("http://example.com") == .link)
        // a sentence that merely mentions a url is not a "link" clip
        #expect(cat("see https://example.com for details") == .plain)
    }

    @Test func detectsHexColors() {
        #expect(cat("#ff8800") == .color)
        #expect(cat("FFF") == .color)
        #expect(cat("#12ab") == .color)          // #RGBA
        #expect(cat("hello") == .plain)
    }

    @Test func detectsCode() {
        #expect(cat("func foo() { return 1 }") == .code)
        #expect(cat("const x = () => { doThing(); }") == .code)
        #expect(cat("just a normal sentence here") == .plain)
    }

    @Test func nonTextKindsKeepTheirCategory() {
        #expect(ContentClassifier.classify(kind: "image", text: nil) == .image)
        #expect(ContentClassifier.classify(kind: "file", text: nil) == .file)
    }

    @Test func ingestStoresAndFiltersByCategory() async throws {
        let store = try Store.temporary(config: .init(maxItems: 100, maxAgeDays: nil))
        func ingestText(_ s: String, _ h: String) async throws {
            try await store.ingest(CapturedItem(
                kind: "text", title: s, contentHash: h,
                representations: [Representation(uti: "public.utf8-plain-text",
                                                 bytes: Data(s.utf8), isImage: false)]),
                nowMillis: Int64(1_000 + h.count))
        }
        try await ingestText("https://a.com", "l")
        try await ingestText("func f(){}", "c")
        try await ingestText("plain words", "p")

        let links = try await store.listItems(limit: 10, category: "link")
        #expect(links.map(\.title) == ["https://a.com"])
        let code = try await store.listItems(limit: 10, category: "code")
        #expect(code.map(\.title) == ["func f(){}"])
        #expect(try await store.listItems(limit: 10).count == 3)   // no filter = all
    }
}
