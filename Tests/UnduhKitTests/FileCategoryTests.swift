import XCTest
@testable import UnduhKit

final class FileCategoryTests: XCTestCase {
    func testKnownExtensions() {
        XCTAssertEqual(FileCategory.classify(fileName: "film.MP4"), .video)
        XCTAssertEqual(FileCategory.classify(fileName: "lagu.flac"), .audio)
        XCTAssertEqual(FileCategory.classify(fileName: "foto.heic"), .image)
        XCTAssertEqual(FileCategory.classify(fileName: "laporan.pdf"), .document)
        XCTAssertEqual(FileCategory.classify(fileName: "arsip.zip"), .archive)
        XCTAssertEqual(FileCategory.classify(fileName: "installer.dmg"), .archive)
        XCTAssertEqual(FileCategory.classify(fileName: "app.apk"), .application)
    }

    func testUnknownAndMissingExtension() {
        XCTAssertEqual(FileCategory.classify(fileName: "data.xyz"), .other)
        XCTAssertEqual(FileCategory.classify(fileName: "README"), .other)
    }
}
