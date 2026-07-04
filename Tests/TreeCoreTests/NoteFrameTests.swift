import Testing
@testable import TreeCore

@Suite struct NoteFrameTests {
    @Test func roundTrips() {
        let frame = NoteFrame(x: 100, y: 200, w: 240, h: 160)
        let json = try! #require(frame.jsonString())
        #expect(NoteFrame.from(json: json) == frame)
    }

    @Test func decodesNilAndGarbageSafely() {
        #expect(NoteFrame.from(json: nil) == nil)
        #expect(NoteFrame.from(json: "not json") == nil)
    }
}
