@testable import AppBundle
import Common
import XCTest

@MainActor
final class NativeFullscreenAppIdsTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }
    override func tearDown() async throws { config.nativeFullscreenAppIds = [] }

    func testListedAppUsesMacosNativeFullscreen() { // e.g. Screen Sharing locks its aspect ratio
        let window = TestWindow.new(id: 1, parent: Workspace.get(byName: name).rootTilingContainer)
        config.nativeFullscreenAppIds = ["bobko.AeroSpace.test-app"]
        assertTrue(window.usesMacosNativeFullscreen)
        config.nativeFullscreenAppIds = []
        assertFalse(window.usesMacosNativeFullscreen)
    }

    func testParseConfig() {
        let result = parseConfig("native-fullscreen-app-ids = ['com.apple.ScreenSharing']")
        assertEquals(result.errors, [])
        assertEquals(result.config.nativeFullscreenAppIds, ["com.apple.ScreenSharing"])
    }
}
