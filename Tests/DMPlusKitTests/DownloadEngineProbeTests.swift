import XCTest
@testable import DMPlusKit

private final class NotFoundStub: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 404,
                                       httpVersion: nil, headerFields: ["Content-Length": "577"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(count: 577))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class DownloadEngineProbeTests: XCTestCase {
    func testProbeThrowsClearStatusOn404() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [NotFoundStub.self]
        let engine = DownloadEngine(session: URLSession(configuration: config))
        do {
            _ = try await engine.probe(URL(string: "https://example.com/uji.zip")!)
            XCTFail("probe seharusnya gagal untuk 404")
        } catch let error as DownloadEngineError {
            XCTAssertEqual(error, .httpStatus(404))
            XCTAssertEqual(error.localizedDescription, "Server menjawab HTTP 404")
        } catch {
            XCTFail("error tak terduga: \(error)")
        }
    }
}
