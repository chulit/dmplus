import XCTest
@testable import UnduhKit

final class DownloadItemTests: XCTestCase {
    func testProgressFraction() {
        let known = DownloadItem(url: URL(string: "https://x.co/f.zip")!, fileName: "f.zip",
                                 totalBytes: 200, downloadedBytes: 50)
        XCTAssertEqual(known.progressFraction, 0.25)
        let unknown = DownloadItem(url: URL(string: "https://x.co/f.zip")!, fileName: "f.zip")
        XCTAssertNil(unknown.progressFraction, "unknown total must stay nil, never faked")
    }

    func testCategoryDerivedFromFileName() {
        let item = DownloadItem(url: URL(string: "https://x.co/v.mkv")!, fileName: "v.mkv")
        XCTAssertEqual(item.category, .video)
    }
}
