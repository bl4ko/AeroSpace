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

    func testFullscreenComesBackWhenPopupFloats() async throws { // Login popups tile briefly before a script floats them
        let workspace = Workspace.get(byName: name)
        let browser = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        assertTrue(browser.focusWindow())
        browser.isFullscreen = true
        try await workspace.layoutWorkspace()
        let popup = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        assertTrue(popup.focusWindow())
        try await workspace.layoutWorkspace()

        popup.bind(to: workspace.floatingWindowsContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        try await workspace.layoutWorkspace()

        assertTrue(browser.isFullscreen)
        assertFalse(popup.isFullscreen)
    }

    func testFullscreenComesBackWhenPopupCloses() async throws {
        let workspace = Workspace.get(byName: name)
        let browser = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        assertTrue(browser.focusWindow())
        browser.isFullscreen = true
        try await workspace.layoutWorkspace()
        let popup = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        assertTrue(popup.focusWindow())
        try await workspace.layoutWorkspace()

        popup.unbindFromParent()
        try await workspace.layoutWorkspace()

        assertTrue(browser.isFullscreen)
    }

    func testTurningFullscreenOffKeepsItOff() async throws {
        let workspace = Workspace.get(byName: name)
        let w1 = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        let w2 = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        assertTrue(w1.focusWindow())
        w1.isFullscreen = true
        try await workspace.layoutWorkspace()

        w1.isFullscreen = false
        try await workspace.layoutWorkspace()
        assertTrue(w2.focusWindow())
        try await workspace.layoutWorkspace()

        assertFalse(w1.isFullscreen)
        assertFalse(w2.isFullscreen)
    }

    func testFullscreenComesBackWhenNewWindowMovesAway() async throws { // e.g. screenshot tools caught by a catch-all rule
        let workspace = Workspace.get(byName: name)
        let browser = TestWindow.new(id: 1, parent: workspace.rootTilingContainer)
        assertTrue(browser.focusWindow())
        browser.isFullscreen = true
        try await workspace.layoutWorkspace()
        let window = TestWindow.new(id: 2, parent: workspace.rootTilingContainer)
        assertTrue(window.focusWindow())
        try await workspace.layoutWorkspace()

        window.bind(to: Workspace.get(byName: "other").rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        assertTrue(browser.focusWindow())
        try await workspace.layoutWorkspace()

        assertTrue(browser.isFullscreen)
        assertFalse(window.isFullscreen)
    }
}
