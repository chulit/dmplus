import XCTest
@testable import DMPlusKit

final class BatchURLExpanderTests: XCTestCase {
    func testExpandWithPadding() {
        let urls = BatchURLExpander.expand("https://x.co/foto*.jpg", range: 8...10)
        XCTAssertEqual(urls.map(\.absoluteString),
                       ["https://x.co/foto08.jpg", "https://x.co/foto09.jpg", "https://x.co/foto10.jpg"])
    }

    func testNoWildcard() {
        XCTAssertFalse(BatchURLExpander.containsWildcard("https://x.co/a.zip"))
        XCTAssertEqual(BatchURLExpander.expand("https://x.co/a.zip", range: 1...3).count, 1)
    }
}

final class LinkExtractorTests: XCTestCase {
    private let base = URL(string: "https://contoh.com/halaman/index.html")!

    func testExtractResolveDedup() {
        let html = """
        <a href="file1.zip">a</a>
        <a href="/abs/film.mp4">b</a>
        <a HREF='file1.zip'>dup</a>
        <img src="gambar.png">
        <a href="javascript:void(0)">x</a>
        <a href="mailto:a@b.co">m</a>
        """
        let links = LinkExtractor.extract(from: html, baseURL: base)
        XCTAssertEqual(links.map { $0.url.absoluteString }, [
            "https://contoh.com/halaman/file1.zip",
            "https://contoh.com/abs/film.mp4",
            "https://contoh.com/halaman/gambar.png",
        ])
        XCTAssertEqual(links[0].category, .archive)
        XCTAssertEqual(links[1].category, .video)
    }

    func testFilterByExtension() {
        let links = LinkExtractor.extract(
            from: "<a href=\"a.zip\">1</a><a href=\"b.mp4\">2</a>", baseURL: base)
        XCTAssertEqual(LinkExtractor.filter(links, extensions: ["mp4"]).count, 1)
        XCTAssertEqual(LinkExtractor.filter(links, extensions: []).count, 2)
    }
}

final class FileNameResolverTests: XCTestCase {
    func testUniqueNames() {
        XCTAssertEqual(FileNameResolver.uniqueName(desired: "a.zip", existing: []), "a.zip")
        XCTAssertEqual(FileNameResolver.uniqueName(desired: "a.zip", existing: ["a.zip"]), "a (1).zip")
        XCTAssertEqual(FileNameResolver.uniqueName(
            desired: "a.zip", existing: ["a.zip", "a (1).zip"]), "a (2).zip")
        XCTAssertEqual(FileNameResolver.uniqueName(desired: "README", existing: ["README"]), "README (1)")
    }
}

final class RetryPolicyTests: XCTestCase {
    func testBackoffAndCap() {
        let policy = RetryPolicy(maxAttempts: 3, baseDelay: 2, maxDelay: 5)
        XCTAssertEqual(policy.delay(forAttempt: 1), 2)
        XCTAssertEqual(policy.delay(forAttempt: 2), 4)
        XCTAssertEqual(policy.delay(forAttempt: 3), 5)
        XCTAssertNil(policy.delay(forAttempt: 4))
    }

    func testDisabled() {
        XCTAssertNil(RetryPolicy(maxAttempts: 0).delay(forAttempt: 1))
    }
}
