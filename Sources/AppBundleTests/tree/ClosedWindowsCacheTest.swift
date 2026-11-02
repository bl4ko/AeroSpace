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

    func testReturningFloatingWindowLeavesOtherWorkspacesAlone() async throws {
        let tiled = Workspace.get(byName: "tiled")
        let w1 = TestWindow.new(id: 1, parent: tiled.rootTilingContainer)
        TestWindow.new(id: 2, parent: tiled.rootTilingContainer)
        assertTrue(w1.focusWindow())
        let screenshot = TestWindow.new(id: 3, parent: Workspace.get(byName: "other").floatingWindowsContainer)
        cacheClosedWindowIfNeeded()

        assertTrue(try await restoreClosedWindowsCacheIfNeeded(newlyDetectedWindow: screenshot))

        assertEquals(tiled.rootTilingContainer.layoutDescription, .h_tiles([.window(1), .window(2)]))
        assertEquals(tiled.rootTilingContainer.mostRecentWindowRecursive, w1)
    }
}
