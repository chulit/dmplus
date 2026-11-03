import XCTest
@testable import DMPlusKit

final class SpeedHistoryTests: XCTestCase {
    func testCapacityDropsOldest() {
        var history = SpeedHistory(capacity: 3)
        [1, 2, 3, 4].forEach { history.append(Double($0)) }
        XCTAssertEqual(history.samples, [2, 3, 4])
        XCTAssertEqual(history.latest, 4)
        XCTAssertEqual(history.peak, 4)
    }

    func testNormalized() {
        var history = SpeedHistory()
        history.append(50)
        history.append(100)
        XCTAssertEqual(history.normalized, [0.5, 1.0])
    }

    func testEmptyAndNegativeClamped() {
        var history = SpeedHistory()
        XCTAssertEqual(history.normalized, [])
        history.append(-5)
        XCTAssertEqual(history.samples, [0])
        XCTAssertEqual(history.normalized, [0])
    }
}
