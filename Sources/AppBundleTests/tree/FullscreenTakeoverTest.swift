@testable import AppBundle
import Common
import XCTest

@MainActor
final class FullscreenTakeoverTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testFocusedWindowTakesOverFullscreen() async throws {
        let workspace = Workspace.get(byName: name)
        let w1 = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let w2 = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        assertTrue(w1.focusWindow())
        w1.isFullscreen = true
        w1.noOuterGapsInFullscreen = true

        assertTrue(w2.focusWindow())
        try await workspace.layoutWorkspace()

        assertFalse(w1.isFullscreen)
        assertTrue(w2.isFullscreen)
        assertTrue(w2.noOuterGapsInFullscreen)
        assertNil(w2.lastAppliedLayoutPhysicalRect)
    }

    func testFocusingFloatingWindowKeepsFullscreen() async throws {
        let workspace = Workspace.get(byName: name)
        let w1 = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let floating = TestWindow.new(id: 2, parent: workspace.floatingWindowsContainer)
        assertTrue(w1.focusWindow())
        w1.isFullscreen = true

        assertTrue(floating.focusWindow())
        try await workspace.layoutWorkspace()

        assertTrue(w1.isFullscreen)
    }
}
