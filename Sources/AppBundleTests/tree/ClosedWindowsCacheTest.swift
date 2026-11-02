@testable import AppBundle
import Common
import XCTest

@MainActor
final class ClosedWindowsCacheTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testReturningWindowKeepsVisibleWorkspace() async throws { // e.g. macshot hides its window while capturing
        let old = Workspace.get(byName: "old")
        let window = TestWindow.new(id: 1, parent: old.rootTilingContainer)
        assertTrue(old.focusWorkspace())
        cacheClosedWindowIfNeeded()
        let current = Workspace.get(byName: "current")
        TestWindow.new(id: 2, parent: current.rootTilingContainer)
        assertTrue(current.focusWorkspace())

        assertTrue(try await restoreClosedWindowsCacheIfNeeded(newlyDetectedWindow: window))

        assertEquals(mainMonitor.activeWorkspace, current)
    }
}
