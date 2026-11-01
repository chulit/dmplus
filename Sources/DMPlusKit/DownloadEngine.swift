import Foundation

/// What a probe learns about a URL before downloading.
public struct ProbeResult: Equatable, Sendable {
    public var totalBytes: Int64?
    public var acceptsRanges: Bool
    public var suggestedFileName: String
}

public enum DownloadEngineError: Error, Equatable {
    case httpStatus(Int)
    case sizeMismatch(expected: Int64, actual: Int64)
    case rangeNotHonored
}

/// Segmented download engine: the core of DMPlus.
///
/// - Probes the server (HEAD, falling back to a 1-byte ranged GET).
/// - If the server accepts ranges and the size is known, splits the file
///   with `SegmentPlanner` and downloads the segments concurrently, each
///   to its own `.segN.part` file next to the destination.
/// - Pause = cancel the calling task. Segment part files stay on disk, and
///   the next run resumes each segment from the bytes it already has.
/// - When ranges are unsupported, falls back to one stream written to
///   `.part`, resuming with a Range request when a part file exists.
public final class DownloadEngine: @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Probe

    public func probe(_ url: URL) async throws -> ProbeResult {
        var head = URLRequest(url: url)
        head.httpMethod = "HEAD"
        if let (data, response) = try? await session.data(for: head),
           let http = response as? HTTPURLResponse, http.statusCode == 200 {
            _ = data
            let total = http.expectedContentLength >= 0 ? http.expectedContentLength : nil
            let ranges = (http.value(forHTTPHeaderField: "Accept-Ranges") ?? "")
                .lowercased().contains("bytes")
            return ProbeResult(totalBytes: total, acceptsRanges: ranges,
                               suggestedFileName: Self.fileName(for: url, response: http))
        }
        // Fallback: ask for a single byte and read Content-Range.
        var get = URLRequest(url: url)
        get.setValue("bytes=0-0", forHTTPHeaderField: "Range")
        let (_, response) = try await session.data(for: get)
        guard let http = response as? HTTPURLResponse else {
            return ProbeResult(totalBytes: nil, acceptsRanges: false,
                               suggestedFileName: Self.fileName(for: url, response: nil))
        }
        if http.statusCode == 206,
           let range = http.value(forHTTPHeaderField: "Content-Range"),
           let totalText = range.split(separator: "/").last,
           let total = Int64(totalText) {
            return ProbeResult(totalBytes: total, acceptsRanges: true,
                               suggestedFileName: Self.fileName(for: url, response: http))
        }
        let total = http.expectedContentLength >= 0 ? http.expectedContentLength : nil
        return ProbeResult(totalBytes: total, acceptsRanges: false,
                           suggestedFileName: Self.fileName(for: url, response: http))
    }

    private static func fileName(for url: URL, response: HTTPURLResponse?) -> String {
        if let suggested = response?.suggestedFilename, !suggested.isEmpty {
            return suggested
        }
        let last = url.lastPathComponent
        return last.isEmpty ? "download" : last.removingPercentEncoding ?? last
    }

    // MARK: - Download

    /// Downloads `url` to `destination`, reporting cumulative bytes on
    /// `onProgress`. Throws `CancellationError` when the task is cancelled
    /// (that is the pause signal — part files remain for resume).
    public func download(url: URL,
                         to destination: URL,
                         probe: ProbeResult,
                         segmentCount: Int = 8,
                         onProgress: @escaping @Sendable (Int64) -> Void) async throws {
        if let total = probe.totalBytes, probe.acceptsRanges, total > 0 {
            try await downloadSegmented(url: url, to: destination, totalBytes: total,
                                        segmentCount: segmentCount, onProgress: onProgress)
        } else {
            try await downloadSingleStream(url: url, to: destination,
                                           acceptsRanges: probe.acceptsRanges,
                                           onProgress: onProgress)
        }
    }

    private func downloadSegmented(url: URL, to destination: URL, totalBytes: Int64,
                                   segmentCount: Int,
                                   onProgress: @escaping @Sendable (Int64) -> Void) async throws {
        let segments = SegmentPlanner.plan(totalBytes: totalBytes, maxSegments: segmentCount)
        let fm = FileManager.default
        try fm.createDirectory(at: destination.deletingLastPathComponent(),
                               withIntermediateDirectories: true)

        // Bytes already on disk from a previous (paused) run.
        var perSegment = [Int64](repeating: 0, count: segments.count)
        for segment in segments {
            let part = Self.partURL(for: destination, segmentIndex: segment.index)
            if let size = try? fm.attributesOfItem(atPath: part.path)[.size] as? Int64 {
                perSegment[segment.index] = min(size, segment.length)
            }
        }
        let counter = ProgressCounter(initial: perSegment.reduce(0, +), onProgress: onProgress)
        onProgress(counter.value)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for segment in segments {
                let already = perSegment[segment.index]
                guard let remaining = SegmentPlanner.remaining(segment, downloadedWithinSegment: already)
                else { continue }
                group.addTask {
                    try await self.downloadSegment(url: url, segment: remaining,
                        partURL: Self.partURL(for: destination, segmentIndex: segment.index),
                        appending: already > 0, counter: counter)
                }
            }
            try await group.waitForAll()
        }

        // Assemble segments in order, then verify the total size.
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        fm.createFile(atPath: destination.path, contents: nil)
        let out = try FileHandle(forWritingTo: destination)
        for segment in segments {
            let part = Self.partURL(for: destination, segmentIndex: segment.index)
            let input = try FileHandle(forReadingFrom: part)
            while let chunk = try input.read(upToCount: 1 << 20), !chunk.isEmpty {
                try out.write(contentsOf: chunk)
            }
            try input.close()
            try fm.removeItem(at: part)
        }
        try out.close()
        let actual = (try fm.attributesOfItem(atPath: destination.path)[.size] as? Int64) ?? -1
        guard actual == totalBytes else {
            throw DownloadEngineError.sizeMismatch(expected: totalBytes, actual: actual)
        }
    }

    private func downloadSegment(url: URL, segment: ByteSegment, partURL: URL,
                                 appending: Bool,
                                 counter: ProgressCounter) async throws {
        var request = URLRequest(url: url)
        request.setValue("bytes=\(segment.start)-\(segment.end)", forHTTPHeaderField: "Range")
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw DownloadEngineError.httpStatus(-1)
        }
        guard http.statusCode == 206 else {
            throw DownloadEngineError.rangeNotHonored
        }
        let fm = FileManager.default
        if !appending, fm.fileExists(atPath: partURL.path) { try fm.removeItem(at: partURL) }
        if !fm.fileExists(atPath: partURL.path) { fm.createFile(atPath: partURL.path, contents: nil) }
        let handle = try FileHandle(forWritingTo: partURL)
        if appending { _ = try handle.seekToEnd() }
        var buffer = Data()
        buffer.reserveCapacity(1 << 16)
        for try await byte in bytes {
            try Task.checkCancellation()
            buffer.append(byte)
            if buffer.count >= 1 << 16 {
                try handle.write(contentsOf: buffer)
                counter.add(Int64(buffer.count))
                buffer.removeAll(keepingCapacity: true)
            }
        }
        if !buffer.isEmpty {
            try handle.write(contentsOf: buffer)
            counter.add(Int64(buffer.count))
        }
        try handle.close()
    }

    private func downloadSingleStream(url: URL, to destination: URL, acceptsRanges: Bool,
                                      onProgress: @escaping @Sendable (Int64) -> Void) async throws {
        let fm = FileManager.default
        try fm.createDirectory(at: destination.deletingLastPathComponent(),
                               withIntermediateDirectories: true)
        let part = destination.appendingPathExtension("part")
        var existing: Int64 = 0
        if acceptsRanges, let size = try? fm.attributesOfItem(atPath: part.path)[.size] as? Int64 {
            existing = size
        }
        var request = URLRequest(url: url)
        if existing > 0 { request.setValue("bytes=\(existing)-", forHTTPHeaderField: "Range") }
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw DownloadEngineError.httpStatus(-1)
        }
        if existing > 0, http.statusCode == 200 {
            // Server ignored our Range: start over from zero.
            existing = 0
            try? fm.removeItem(at: part)
        } else if ![200, 206].contains(http.statusCode) {
            throw DownloadEngineError.httpStatus(http.statusCode)
        }
        if !fm.fileExists(atPath: part.path) { fm.createFile(atPath: part.path, contents: nil) }
        let handle = try FileHandle(forWritingTo: part)
        if existing > 0 { _ = try handle.seekToEnd() }
        let counter = ProgressCounter(initial: existing, onProgress: onProgress)
        onProgress(existing)
        var buffer = Data()
        buffer.reserveCapacity(1 << 16)
        for try await byte in bytes {
            try Task.checkCancellation()
            buffer.append(byte)
            if buffer.count >= 1 << 16 {
                try handle.write(contentsOf: buffer)
                counter.add(Int64(buffer.count))
                buffer.removeAll(keepingCapacity: true)
            }
        }
        if !buffer.isEmpty {
            try handle.write(contentsOf: buffer)
            counter.add(Int64(buffer.count))
        }
        try handle.close()
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try fm.moveItem(at: part, to: destination)
    }

    static func partURL(for destination: URL, segmentIndex: Int) -> URL {
        destination.appendingPathExtension("seg\(segmentIndex).part")
    }
}

/// Thread-safe cumulative progress counter shared by segment tasks.
final class ProgressCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Int64
    private let onProgress: @Sendable (Int64) -> Void

    init(initial: Int64, onProgress: @escaping @Sendable (Int64) -> Void) {
        _value = initial
        self.onProgress = onProgress
    }

    var value: Int64 { lock.lock(); defer { lock.unlock() }; return _value }

    func add(_ delta: Int64) {
        lock.lock()
        _value += delta
        let current = _value
        lock.unlock()
        onProgress(current)
    }
}
