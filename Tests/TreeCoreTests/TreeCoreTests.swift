import Testing
@testable import TreeCore

// swift-testing (bundled with the Swift 6 toolchain) rather than XCTest, so the
// suite builds without a full Xcode install (CLT-only) and matches CI.
@Suite struct TreeCoreTests {
    @Test func versionIsSemver() {
        let parts = TreeCore.version.split(separator: ".")
        #expect(parts.count == 3)   // MAJOR.MINOR.PATCH
        #expect(parts.allSatisfy { Int($0) != nil })
    }
}
