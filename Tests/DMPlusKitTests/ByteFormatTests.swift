import XCTest
@testable import DMPlusKit

final class ByteFormatTests: XCTestCase {
    func testFormat() {
        XCTAssertEqual(ByteFormat.format(0), "0 B")
        XCTAssertEqual(ByteFormat.format(512), "512 B")
        XCTAssertEqual(ByteFormat.format(1024), "1 KB")
        XCTAssertEqual(ByteFormat.format(1536), "1.5 KB")
        XCTAssertEqual(ByteFormat.format(10 * 1024 * 1024), "10 MB")
        XCTAssertEqual(ByteFormat.format(3 * 1024 * 1024 * 1024), "3 GB")
    }

    func testSpeed() {
        XCTAssertEqual(ByteFormat.formatSpeed(0), "0 B/s")
        XCTAssertEqual(ByteFormat.formatSpeed(2048), "2 KB/s")
    }

    func testProgressHonesty() {
        XCTAssertEqual(ByteFormat.formatProgress(downloaded: 512, total: nil), "512 B")
        XCTAssertEqual(ByteFormat.formatProgress(downloaded: 512, total: 1024), "512 B of 1 KB")
    }
}
