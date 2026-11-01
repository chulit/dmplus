import Foundation

/// Rolling-window download speed. Pure value type; time is injected so
/// tests don't depend on the wall clock.
public struct SpeedMeter: Sendable {
    public private(set) var samples: [(at: Date, bytes: Int64)] = []
    public let window: TimeInterval

    public init(window: TimeInterval = 3) {
        self.window = window
    }

    public mutating func record(bytes: Int64, at date: Date = Date()) {
        samples.append((at: date, bytes: bytes))
        samples.removeAll { date.timeIntervalSince($0.at) > window }
    }

    /// Bytes per second across the current window; 0 when not measurable.
    public func speed(at date: Date = Date()) -> Double {
        guard let first = samples.first, let last = samples.last else { return 0 }
        let dt = last.at.timeIntervalSince(first.at)
        guard dt > 0 else { return 0 }
        _ = date // window pruning happens in record(); `at` kept for API symmetry
        return Double(last.bytes - first.bytes) / dt
    }

    public mutating func reset() { samples.removeAll() }
}
