import Foundation

/// Estimated time remaining, the way IDM's "Time left" column computes it:
/// remaining bytes divided by current speed. Returns `nil` whenever either
/// input is unknown — an unknown ETA is displayed as "—", never guessed.
public enum ETACalculator {
    public static func remainingSeconds(totalBytes: Int64?, downloadedBytes: Int64,
                                        bytesPerSecond: Double) -> TimeInterval? {
        guard let totalBytes, bytesPerSecond > 0 else { return nil }
        let remaining = totalBytes - downloadedBytes
        guard remaining > 0 else { return 0 }
        return Double(remaining) / bytesPerSecond
    }

    /// Indonesian short duration: "45 dtk", "3 mnt 20 dtk", "1 jam 5 mnt".
    public static func format(_ seconds: TimeInterval?) -> String {
        guard let seconds else { return "—" }
        if seconds < 1 { return "0 dtk" }
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 { return "\(hours) jam \(minutes) mnt" }
        if minutes > 0 { return "\(minutes) mnt \(secs) dtk" }
        return "\(secs) dtk"
    }
}
