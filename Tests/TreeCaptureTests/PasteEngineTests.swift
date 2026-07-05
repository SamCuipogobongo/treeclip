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
            .paste(row: row, options: [], nowMillis: 2_000)

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
            .paste(row: row, options: [], nowMillis: 2_000)

        #expect(plan == .raw)
        #expect(NSPasteboard.general.string(forType: .string) == "npm run build")
        #expect(!FileManager.default.fileExists(atPath: dir.path))  // no handoff file written
    }

    @Test func nonTerminalPastesRawEvenIfLong() async throws {
        let (store, row) = try await textStore(String(repeating: "x\n", count: 100))
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ho-\(UUID().uuidString)")
        let plan = await engine(store, handoffDir: dir, front: "com.apple.TextEdit")
            .paste(row: row, options: [], nowMillis: 2_000)
        #expect(plan == .raw)
    }

    @Test func copyOnlyPutsContentOnClipboardWithoutHandoff() async throws {
        // Long text in a terminal would normally @file; copy-only must instead
        // put the actual content on the clipboard (no routing).
        let (store, row) = try await textStore(String(repeating: "line\n", count: 50))
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ho-\(UUID().uuidString)")
        let plan = await engine(store, handoffDir: dir, front: "com.apple.Terminal")
            .paste(row: row, options: .copyOnly, nowMillis: 2_000)
        #expect(plan == .raw)
        #expect(!FileManager.default.fileExists(atPath: dir.path))          // no @file
        #expect(NSPasteboard.general.string(forType: .string)?.hasPrefix("line") == true)
    }

    @Test func plainTextStripsToPlainRepresentation() async throws {
        let store = try Store.temporary()
        // Item with both rich (rtf) and plain reps.
        try await store.ingest(CapturedItem(
            kind: "text", title: "styled", contentHash: "s",
            representations: [
                Representation(uti: "public.utf8-plain-text", bytes: Data("plain body".utf8), isImage: false),
                Representation(uti: "public.rtf", bytes: Data("{\\rtf styled}".utf8), isImage: false),
            ]), nowMillis: 1_000)
        let row = try #require(try await store.listItems(limit: 1).first)
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ho-\(UUID().uuidString)")
        _ = await engine(store, handoffDir: dir, front: "com.apple.TextEdit")
            .paste(row: row, options: [.plainText, .copyOnly], nowMillis: 2_000)
        // Only the plain text lands on the clipboard; no RTF.
        #expect(NSPasteboard.general.string(forType: .string) == "plain body")
        #expect(NSPasteboard.general.data(forType: .rtf) == nil)
    }
}
