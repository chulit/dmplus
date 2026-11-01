import Foundation

/// One byte range of a file, downloaded by one connection.
/// `end` is inclusive, matching HTTP `Range: bytes=start-end` semantics.
public struct ByteSegment: Equatable, Sendable {
    public let index: Int
    public let start: Int64
    public let end: Int64

    public var length: Int64 { end - start + 1 }

    public init(index: Int, start: Int64, end: Int64) {
        self.index = index
        self.start = start
        self.end = end
    }
}

/// Pure planner that splits a file into per-connection ranges.
/// This is the "download logic accelerator" idea: N connections, N ranges.
public enum SegmentPlanner {
    /// Files smaller than this are never split.
    public static let defaultMinSegmentSize: Int64 = 1 << 20 // 1 MiB

    public static func plan(totalBytes: Int64,
                            maxSegments: Int,
                            minSegmentSize: Int64 = defaultMinSegmentSize) -> [ByteSegment] {
        guard totalBytes > 0, maxSegments > 1 else {
            return totalBytes > 0 ? [ByteSegment(index: 0, start: 0, end: totalBytes - 1)] : []
        }
        let bySize = Int(totalBytes / max(minSegmentSize, 1))
        let count = max(1, min(maxSegments, bySize))
        guard count > 1 else {
            return [ByteSegment(index: 0, start: 0, end: totalBytes - 1)]
        }
        let base = totalBytes / Int64(count)
        let remainder = totalBytes % Int64(count)
        var segments: [ByteSegment] = []
        var cursor: Int64 = 0
        for i in 0..<count {
            // The first `remainder` segments get one extra byte so the
            // ranges tile the file exactly with no gap or overlap.
            let len = base + (Int64(i) < remainder ? 1 : 0)
            segments.append(ByteSegment(index: i, start: cursor, end: cursor + len - 1))
            cursor += len
        }
        return segments
    }

    /// The still-missing part of a segment after a pause, for resume.
    /// Returns `nil` when the segment is already complete.
    public static func remaining(_ segment: ByteSegment, downloadedWithinSegment: Int64) -> ByteSegment? {
        guard downloadedWithinSegment < segment.length else { return nil }
        let done = max(0, downloadedWithinSegment)
        return ByteSegment(index: segment.index, start: segment.start + done, end: segment.end)
    }
}
