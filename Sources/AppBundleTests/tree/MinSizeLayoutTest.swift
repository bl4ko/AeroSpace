@testable import AppBundle
import Common
import XCTest

@MainActor
final class MinSizeLayoutTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    private func window(_ id: UInt32, _ parent: TilingContainer, minWidth: CGFloat = 0) -> TestWindow {
        let window = TestWindow.new(id: id, parent: parent)
        window.learnedMinSize = CGSize(width: minWidth, height: 0)
        return window
    }

    private func width(_ window: Window) -> CGFloat? { window.lastAppliedLayoutPhysicalRect?.width }

    func testWithoutMinimumsSplitsByWeight() async throws {
        let workspace = Workspace.get(byName: name)
        let w1 = window(1, workspace.rootTilingContainer)
        let w2 = window(2, workspace.rootTilingContainer)

        try await workspace.layoutWorkspace()

        assertEquals(width(w1), 960)
        assertEquals(width(w2), 960)
    }

    func testNeighborShrinksToFitMinimum() async throws {
        let workspace = Workspace.get(byName: name)
        let w1 = window(1, workspace.rootTilingContainer, minWidth: 1200)
        let w2 = window(2, workspace.rootTilingContainer)

        try await workspace.layoutWorkspace()

        assertEquals(width(w1), 1200)
        assertEquals(width(w2), 720)
    }

    func testStacksWhenMinimumsDontFit() async throws {
        let workspace = Workspace.get(byName: name)
        let w1 = window(1, workspace.rootTilingContainer, minWidth: 1200)
        let w2 = window(2, workspace.rootTilingContainer, minWidth: 1000)

        try await workspace.layoutWorkspace()

        let padding = CGFloat(config.accordionPadding)
        assertEquals(w1.lastAppliedLayoutPhysicalRect?.minX, 0)
        assertEquals(width(w1), 1920 - padding)
        assertEquals(w2.lastAppliedLayoutPhysicalRect?.minX, padding)
        assertEquals(width(w2), 1920 - padding)
    }

    func testOnlyTheBranchThatDoesntFitStacks() async throws {
        let workspace = Workspace.get(byName: name)
        let root = workspace.rootTilingContainer
        let w1 = window(1, root, minWidth: 1000)
        let v = TilingContainer(parent: root, adaptiveWeight: 1, .v, .tiles, index: INDEX_BIND_LAST)
        let w2 = window(2, v)
        let h = TilingContainer(parent: v, adaptiveWeight: 1, .h, .tiles, index: INDEX_BIND_LAST)
        let w3 = window(3, h, minWidth: 600)
        let w4 = window(4, h, minWidth: 600)

        try await workspace.layoutWorkspace()

        let padding = CGFloat(config.accordionPadding)
        assertEquals(width(w1), 1000)
        assertEquals(width(w2), 920)
        assertEquals(w3.lastAppliedLayoutPhysicalRect?.minX, 1000)
        assertEquals(width(w3), 920 - padding)
        assertEquals(w4.lastAppliedLayoutPhysicalRect?.minX, 1000 + padding)
        assertEquals(width(w4), 920 - padding)
    }
}
