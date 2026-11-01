@testable import AppBundle
import XCTest

final class RectTest: XCTestCase {
    func testTopLeftToCenter() {
        let monitor = Rect(topLeftX: 0, topLeftY: 33, width: 1728, height: 1084)
        assertEquals(monitor.topLeftToCenter(CGSize(width: 864, height: 600)), CGPoint(x: 432, y: 275))
    }

    func testIsStranded() {
        let monitor = Rect(topLeftX: 0, topLeftY: 0, width: 1728, height: 1117)
        // Parked in the bottom right hide corner: 1px visible
        XCTAssertTrue(Rect(topLeftX: 1727, topLeftY: 1085, width: 864, height: 600).isStranded(outside: monitor))
        // Entirely on another monitor
        XCTAssertTrue(Rect(topLeftX: -387, topLeftY: -1440, width: 864, height: 600).isStranded(outside: monitor))
        // Fully visible
        XCTAssertFalse(Rect(topLeftX: 864, topLeftY: 517, width: 864, height: 600).isStranded(outside: monitor))
        // Dragged mostly off screen by the user, but still grabbable
        XCTAssertFalse(Rect(topLeftX: 1600, topLeftY: 900, width: 864, height: 600).isStranded(outside: monitor))
    }
}
