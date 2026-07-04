import Testing
import Foundation
@testable import TreeCore

@Suite struct AgentRouterTests {
    let cfg = AgentRouteConfig()
    let terminal = "com.apple.Terminal"
    let editor = "com.apple.TextEdit"

    @Test func nonTerminalAlwaysRaw() {
        let longText = String(repeating: "x\n", count: 500)
        #expect(AgentRouter.plan(frontApp: editor, kind: "text", text: longText,
                                 forceRaw: false, config: cfg) == .raw)
    }

    @Test func terminalShortTextIsRaw() {
        #expect(AgentRouter.plan(frontApp: terminal, kind: "text", text: "npm run build",
                                 forceRaw: false, config: cfg) == .raw)
    }

    @Test func terminalLongTextByLinesGoesToFile() {
        let manyLines = String(repeating: "line\n", count: 40)   // > 30 lines
        #expect(AgentRouter.plan(frontApp: terminal, kind: "text", text: manyLines,
                                 forceRaw: false, config: cfg) == .handoffFile(kind: "text", ext: "txt"))
    }

    @Test func terminalLongTextByCharsGoesToFile() {
        let bigLine = String(repeating: "x", count: 5_000)       // > 4000 chars, 1 line
        #expect(AgentRouter.plan(frontApp: terminal, kind: "text", text: bigLine,
                                 forceRaw: false, config: cfg) == .handoffFile(kind: "text", ext: "txt"))
    }

    @Test func terminalImageAlwaysGoesToFile() {
        #expect(AgentRouter.plan(frontApp: terminal, kind: "image", text: nil,
                                 forceRaw: false, config: cfg) == .handoffFile(kind: "image", ext: "png"))
    }

    @Test func forceRawOverridesEverything() {
        let manyLines = String(repeating: "line\n", count: 40)
        #expect(AgentRouter.plan(frontApp: terminal, kind: "text", text: manyLines,
                                 forceRaw: true, config: cfg) == .raw)
    }
}

@Suite struct HandoffStoreTests {
    private func tempDir() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("handoff-\(UUID().uuidString)", isDirectory: true)
    }

    @Test func writeCreatesReadableFile() throws {
        let store = HandoffStore(directory: tempDir())
        let url = try store.write(bytes: Data("hello agent".utf8), ext: "txt", nowMillis: 1_000)
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(try String(contentsOf: url, encoding: .utf8) == "hello agent")
        #expect(url.pathExtension == "txt")
    }

    @Test func reclaimRemovesOnlyExpired() throws {
        let store = HandoffStore(directory: tempDir())
        let day: Int64 = 86_400_000
        _ = try store.write(bytes: Data([1]), ext: "txt", nowMillis: 0)          // old
        let fresh = try store.write(bytes: Data([2]), ext: "txt", nowMillis: 10 * day)  // recent
        let removed = store.reclaim(nowMillis: 10 * day, maxAgeMillis: 7 * day)
        #expect(removed == 1)
        #expect(FileManager.default.fileExists(atPath: fresh.path))
    }
}
