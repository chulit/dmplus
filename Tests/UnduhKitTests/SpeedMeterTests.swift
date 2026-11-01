import XCTest
@testable import UnduhKit

final class SpeedMeterTests: XCTestCase {
    func testSpeedAcrossWindow() {
        var meter = SpeedMeter(window: 10)
        let t0 = Date(timeIntervalSince1970: 1000)
        meter.record(bytes: 0, at: t0)
        meter.record(bytes: 3000, at: t0.addingTimeInterval(3))
        XCTAssertEqual(meter.speed(at: t0.addingTimeInterval(3)), 1000, accuracy: 0.001)
    }

    func testOldSamplesArePruned() {
        var meter = SpeedMeter(window: 3)
        let t0 = Date(timeIntervalSince1970: 0)
        meter.record(bytes: 0, at: t0)
        meter.record(bytes: 100, at: t0.addingTimeInterval(10))
        XCTAssertEqual(meter.samples.count, 1)
        XCTAssertEqual(meter.speed(), 0)
    }
}
