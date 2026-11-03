import XCTest
@testable import DMPlusKit

private final class CookieCaptureStub: URLProtocol {
    static var lastCookie: String?
    static var lastReferer: String?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        CookieCaptureStub.lastCookie = request.value(forHTTPHeaderField: "Cookie")
        CookieCaptureStub.lastReferer = request.value(forHTTPHeaderField: "Referer")
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                       headerFields: ["Content-Length": "10",
                                                      "Accept-Ranges": "bytes"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class CookieForwardTests: XCTestCase {
    func testProbeForwardsBrowserSession() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CookieCaptureStub.self]
        let session = URLSession(configuration: config)
        let engine = DownloadEngine(session: session)
        _ = try await engine.probe(URL(string: "https://example.com/file.bin")!,
                                    cookie: "session=abc123", referer: "https://example.com/page")
        XCTAssertEqual(CookieCaptureStub.lastCookie, "session=abc123")
        XCTAssertEqual(CookieCaptureStub.lastReferer, "https://example.com/page")
    }

    func testItemRoundTripsSession() throws {
        let item = DownloadItem(url: URL(string: "https://example.com/f.zip")!,
                                fileName: "f.zip", cookie: "a=b", referer: "https://example.com/")
        let data = try JSONEncoder().encode(item)
        let back = try JSONDecoder().decode(DownloadItem.self, from: data)
        XCTAssertEqual(back.cookie, "a=b")
        XCTAssertEqual(back.referer, "https://example.com/")
    }
}
