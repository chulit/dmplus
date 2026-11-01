import XCTest
@testable import DMPlusKit

final class SegmentPlannerTests: XCTestCase {
    func testTilesExactlyWithRemainder() {
        let segments = SegmentPlanner.plan(totalBytes: 10, maxSegments: 4, minSegmentSize: 1)
        XCTAssertEqual(segments.count, 4)
        XCTAssertEqual(segments.map(\.length), [3, 3, 2, 2])
        XCTAssertEqual(segments.first?.start, 0)
        XCTAssertEqual(segments.last?.end, 9)
        for (a, b) in zip(segments, segments.dropFirst()) {
            XCTAssertEqual(a.end + 1, b.start, "segments must tile with no gap/overlap")
        }
    }

    func testSmallFileIsSingleSegment() {
        let segments = SegmentPlanner.plan(totalBytes: 500, maxSegments: 8)
        XCTAssertEqual(segments, [ByteSegment(index: 0, start: 0, end: 499)])
    }

    func testSegmentCountCappedByMinSegmentSize() {
        // 3 MiB with 1 MiB minimum -> at most 3 segments even if 8 requested.
        let segments = SegmentPlanner.plan(totalBytes: 3 << 20, maxSegments: 8)
        XCTAssertEqual(segments.count, 3)
    }

    func testEmptyFilePlansNothing() {
        XCTAssertTrue(SegmentPlanner.plan(totalBytes: 0, maxSegments: 8).isEmpty)
    }

    func testRemainingForResume() {
        let segment = ByteSegment(index: 2, start: 100, end: 199)
        XCTAssertEqual(SegmentPlanner.remaining(segment, downloadedWithinSegment: 40),
                       ByteSegment(index: 2, start: 140, end: 199))
        XCTAssertNil(SegmentPlanner.remaining(segment, downloadedWithinSegment: 100))
    }
}
