import Foundation

/// Deterministic byte/speed formatting (1024-based, one decimal, ".0" trimmed).
/// Implemented manually — not via ByteCountFormatter — so tests are stable
/// across OS versions and locales.
public enum ByteFormat {
    private static let units = ["B", "KB", "MB", "GB", "TB", "PB"]

    public static func format(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 B" }
        var value = Double(bytes)
        var unit = 0
        while value >= 1024, unit < units.count - 1 {
            value /= 1024
            unit += 1
        }
        if unit == 0 { return "\(bytes) B" }
        let text = String(format: "%.1f", value).replacingOccurrences(of: ".0", with: "")
        return "\(text) \(units[unit])"
    }

    public static func formatSpeed(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond > 0 else { return "0 B/s" }
        return format(Int64(bytesPerSecond.rounded())) + "/s"
    }

    /// "3.2 MB of 10 MB" — or just the downloaded amount when the total is
    /// unknown (never fabricate a total).
    public static func formatProgress(downloaded: Int64, total: Int64?) -> String {
        guard let total else { return format(downloaded) }
        return "\(format(downloaded)) of \(format(total))"
    }
}
