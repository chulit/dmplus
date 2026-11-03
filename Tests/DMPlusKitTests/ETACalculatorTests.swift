import XCTest
@testable import DMPlusKit

final class ETACalculatorTests: XCTestCase {
    func testRemainingSeconds() {
        XCTAssertEqual(ETACalculator.remainingSeconds(
            totalBytes: 1000, downloadedBytes: 500, bytesPerSecond: 100), 5)
        XCTAssertEqual(ETACalculator.remainingSeconds(
            totalBytes: 1000, downloadedBytes: 1000, bytesPerSecond: 100), 0)
    }

    func testUnknownStaysNil() {
        XCTAssertNil(ETACalculator.remainingSeconds(
            totalBytes: nil, downloadedBytes: 10, bytesPerSecond: 100))
        XCTAssertNil(ETACalculator.remainingSeconds(
            totalBytes: 1000, downloadedBytes: 10, bytesPerSecond: 0))
    }

    func testFormat() {
        XCTAssertEqual(ETACalculator.format(nil), "—")
        XCTAssertEqual(ETACalculator.format(45), "45 dtk")
        XCTAssertEqual(ETACalculator.format(200), "3 mnt 20 dtk")
        XCTAssertEqual(ETACalculator.format(3900), "1 jam 5 mnt")
    }
}
