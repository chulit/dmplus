import XCTest
@testable import DMPlusKit

final class DownloadStoreTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() {
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dmplus-tests-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testRoundTrip() {
        let store = DownloadStore(fileURL: fileURL)
        let item = DownloadItem(url: URL(string: "https://contoh.com/film.mp4")!,
                                fileName: "film.mp4", totalBytes: 2048,
                                downloadedBytes: 512, state: .paused)
        store.save([item])
        XCTAssertEqual(store.load(), [item])
    }

    func testDownloadingComesBackPaused() {
        let store = DownloadStore(fileURL: fileURL)
        let item = DownloadItem(url: URL(string: "https://contoh.com/a.zip")!,
                                fileName: "a.zip", state: .downloading)
        store.save([item])
        XCTAssertEqual(store.load().first?.state, .paused)
    }

    func testMissingFileLoadsEmpty() {
        XCTAssertTrue(DownloadStore(fileURL: fileURL).load().isEmpty)
    }
}
