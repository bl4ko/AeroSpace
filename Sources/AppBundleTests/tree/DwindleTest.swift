@testable import AppBundle
import Common
import XCTest

@MainActor
final class DwindleTest: XCTestCase {
    override func setUp() async throws {
        setUpWorkspacesForTests()
        config.dwindle = true
    }

    private func addWindow(_ id: UInt32, _ workspace: Workspace, rect: Rect? = nil) async throws -> TestWindow {
        // Create elsewhere so that the target workspace's most recent child stays intact, like for real new windows
        let window = TestWindow.new(id: id, parent: Workspace.get(byName: "scratch").rootTilingContainer)
        try await window.relayoutWindow(on: workspace, .cancellable, forceTile: true)
        window.lastAppliedLayoutPhysicalRect = rect
        _ = window.focusWindow()
        return window
    }

    func testSplitsFocusedWindowAlongLongerSide() async throws {
        let workspace = Workspace.get(byName: name)
        _ = try await addWindow(1, workspace, rect: Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 600))
        _ = try await addWindow(2, workspace, rect: Rect(topLeftX: 500, topLeftY: 0, width: 500, height: 600))
        _ = try await addWindow(3, workspace, rect: Rect(topLeftX: 500, topLeftY: 300, width: 500, height: 300))
        _ = try await addWindow(4, workspace)

        assertEquals(workspace.rootTilingContainer.layoutDescription, .h_tiles([
            .window(1),
            .v_tiles([
                .window(2),
                .h_tiles([
                    .window(3),
                    .window(4),
                ]),
            ]),
        ]))
    }

    func testSingleWindowOnPortraitMonitorSplitsVertically() async throws {
        let workspace = Workspace.get(byName: name)
        _ = try await addWindow(1, workspace, rect: Rect(topLeftX: 0, topLeftY: 0, width: 600, height: 1000))
        _ = try await addWindow(2, workspace)

        assertEquals(workspace.rootTilingContainer.layoutDescription, .v_tiles([
            .window(1),
            .window(2),
        ]))
    }

    func testUnknownSizesAlternateOrientation() async throws { // e.g. windows detected at startup
        let workspace = Workspace.get(byName: name)
        for id: UInt32 in 1 ... 4 {
            _ = try await addWindow(id, workspace)
        }

        assertEquals(workspace.rootTilingContainer.layoutDescription, .h_tiles([
            .window(1),
            .v_tiles([
                .window(2),
                .h_tiles([
                    .window(3),
                    .window(4),
                ]),
            ]),
        ]))
    }

    func testMoveNodeToWorkspaceSplitsMostRecentWindow() async throws {
        let target = Workspace.get(byName: "dest")
        _ = try await addWindow(1, target, rect: Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 600))
        _ = try await addWindow(2, target, rect: Rect(topLeftX: 500, topLeftY: 0, width: 500, height: 600))
        assertEquals(TestWindow.new(id: 3, parent: Workspace.get(byName: name).rootTilingContainer).focusWindow(), true)

        await parseCommand("move-node-to-workspace dest").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(target.rootTilingContainer.layoutDescription, .h_tiles([
            .window(1),
            .v_tiles([
                .window(2),
                .window(3),
            ]),
        ]))
    }

    func testDisabledAppendsToParent() async throws {
        config.dwindle = false
        let workspace = Workspace.get(byName: name)
        _ = try await addWindow(1, workspace, rect: Rect(topLeftX: 0, topLeftY: 0, width: 1000, height: 600))
        _ = try await addWindow(2, workspace, rect: Rect(topLeftX: 500, topLeftY: 0, width: 500, height: 600))
        _ = try await addWindow(3, workspace)

        assertEquals(workspace.rootTilingContainer.layoutDescription, .h_tiles([
            .window(1),
            .window(2),
            .window(3),
        ]))
    }
}
