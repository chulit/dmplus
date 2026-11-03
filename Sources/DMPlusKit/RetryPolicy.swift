import Foundation

/// Auto-reconnect policy (IDM retries failed downloads automatically):
/// exponential backoff 2s, 4s, 8s ... capped, with a configurable
/// maximum number of attempts. 0 attempts = retry disabled.
public struct RetryPolicy: Equatable, Sendable {
    public var maxAttempts: Int
    public var baseDelay: TimeInterval
    public var maxDelay: TimeInterval

    public init(maxAttempts: Int = 3, baseDelay: TimeInterval = 2, maxDelay: TimeInterval = 30) {
        self.maxAttempts = max(0, maxAttempts)
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
    }

    /// Delay before retry number `attempt` (1-based); nil when exhausted.
    public func delay(forAttempt attempt: Int) -> TimeInterval? {
        guard attempt >= 1, attempt <= maxAttempts else { return nil }
        return min(maxDelay, baseDelay * pow(2, Double(attempt - 1)))
    }
}
