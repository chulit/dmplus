import Foundation

/// IDM's batch download: a URL containing `*` expands into a numbered
/// series, e.g. `https://x/foto*.jpg` over 1...12 -> foto1.jpg ... foto12.jpg.
/// The number is zero-padded to the width of the largest value.
public enum BatchURLExpander {
    public static func containsWildcard(_ urlString: String) -> Bool {
        urlString.contains("*")
    }

    public static func expand(_ urlString: String, range: ClosedRange<Int>) -> [URL] {
        guard urlString.contains("*") else {
            return URL(string: urlString).map { [$0] } ?? []
        }
        let width = String(range.upperBound).count
        return range.compactMap { n in
            let padded = String(format: "%0\(width)d", n)
            return URL(string: urlString.replacingOccurrences(of: "*", with: padded))
        }
    }
}
