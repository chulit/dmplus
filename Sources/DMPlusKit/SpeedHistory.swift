import Foundation

/// Fixed-capacity series of speed samples (bytes/sec) feeding the
/// per-download speed graph in the progress window — IDM shows the same
/// graph on its download dialog. Pure value type; time is the caller's.
public struct SpeedHistory: Equatable, Sendable {
    public private(set) var samples: [Double] = []
    public let capacity: Int

    public init(capacity: Int = 60) {
        self.capacity = max(1, capacity)
    }

    public mutating func append(_ bytesPerSecond: Double) {
        samples.append(max(0, bytesPerSecond))
        if samples.count > capacity { samples.removeFirst(samples.count - capacity) }
    }

    public var latest: Double { samples.last ?? 0 }
    public var peak: Double { samples.max() ?? 0 }

    /// Samples scaled to 0...1 against the peak, for drawing.
    public var normalized: [Double] {
        let peak = peak
        guard peak > 0 else { return samples.map { _ in 0 } }
        return samples.map { $0 / peak }
    }

    public mutating func reset() { samples.removeAll() }
}
