import Testing
import Foundation
import AppKit
@testable import TreeCapture
import TreeCore

/// Integration tests for the flagship path: terminal + big content → `@file`.
/// Front app is injected and the real ⌘V is suppressed, but the routing, file
/// handoff, and pasteboard write are all real. Note: these mutate the system
/// pasteboard (a clipboard manager's tests touching the clipboard is expected).
@MainActor
@Suite struct PasteEngineTests {
    private func textStore(_ body: String) async throws -> (Store, ListRow) {
        let store = try Store.temporary()
        try await store.ingest(CapturedItem(
            kind: "text", title: String(body.prefix(20)), contentHash: "h-\(body.count)",
            representations: [Representation(uti: "public.utf8-plain-text",
                                             bytes: Data(body.utf8), isImage: false)]
        ), nowMillis: 1_000)
        let row = try #require(try await store.listItems(limit: 1).first)
        return (store, row)
    }

    private func engine(_ store: Store, handoffDir: URL, front: String) -> PasteEngine {
        PasteEngine(store: store, handoff: HandoffStore(directory: handoffDir),
                    ownership: PasteboardOwnership(),
                    frontAppProvider: { front }, synthesizesPaste: false)
    }

    @Test func terminalLongTextBecomesHandoffFile() async throws {
        let (store, row) = try await textStore(String(repeating: "line\n", count: 50))
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ho-\(UUID().uuidString)")
        let plan = await engine(store, handoffDir: dir, front: "com.apple.Terminal")
            .paste(row: row, forceRaw: false, nowMillis: 2_000)

        #expect(plan == .handoffFile(kind: "text", ext: "txt"))
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        #expect(files.count == 1)                                   // wrote one handoff file
        let pasted = NSPasteboard.general.string(forType: .string) ?? ""
        #expect(pasted.hasPrefix("@"))                              // clipboard holds an @path ref
        #expect(pasted.contains(dir.lastPathComponent))
    }

    @Test func terminalShortTextPastesRaw() async throws {
        let (store, row) = try await textStore("npm run build")
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ho-\(UUID().uuidString)")
        let plan = await engine(store, handoffDir: dir, front: "com.apple.Terminal")
            .paste(row: row, forceRaw: false, nowMillis: 2_000)

        #expect(plan == .raw)
        #expect(NSPasteboard.general.string(forType: .string) == "npm run build")
        #expect(!FileManager.default.fileExists(atPath: dir.path))  // no handoff file written
    }

    @Test func nonTerminalPastesRawEvenIfLong() async throws {
        let (store, row) = try await textStore(String(repeating: "x\n", count: 100))
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ho-\(UUID().uuidString)")
        let plan = await engine(store, handoffDir: dir, front: "com.apple.TextEdit")
            .paste(row: row, forceRaw: false, nowMillis: 2_000)
        #expect(plan == .raw)
    }
}
