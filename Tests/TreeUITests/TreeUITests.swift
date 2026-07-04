import Testing
@testable import TreeUI
import TreeCore

@Suite struct TreeUITests {
    @Test func uiTracksCoreVersion() {
        #expect(TreeUI.coreVersion == TreeCore.version)
    }
}
