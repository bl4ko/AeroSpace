@testable import AppBundle
import Common
import XCTest

@MainActor
final class SummonTest: XCTestCase {
    override func setUp() async throws {
        setUpWorkspacesForTests()
        config.summonAppIds = ["bobko.AeroSpace.test-app"]
    }

    func testSummonsWindowFromHiddenWorkspace() {
        let current = Workspace.get(byName: "current")
        assertTrue(current.focusWorkspace())
        let window = TestWindow.new(id: 1, parent: Workspace.get(byName: "hidden").floatingWindowsContainer)

        summonIfNeeded(window)

        assertEquals(window.nodeWorkspace, current)
        assertTrue(window.isFloating)
    }

    func testIgnoresUnlistedApps() {
        config.summonAppIds = []
        assertTrue(Workspace.get(byName: "current").focusWorkspace())
        let hidden = Workspace.get(byName: "hidden")
        let window = TestWindow.new(id: 1, parent: hidden.floatingWindowsContainer)

        summonIfNeeded(window)

        assertEquals(window.nodeWorkspace, hidden)
    }

    func testIgnoresWindowsOnVisibleWorkspace() {
        let current = Workspace.get(byName: "current")
        assertTrue(current.focusWorkspace())
        let window = TestWindow.new(id: 1, parent: current.floatingWindowsContainer)

        summonIfNeeded(window)

        assertEquals(window.nodeWorkspace, current)
    }
}
