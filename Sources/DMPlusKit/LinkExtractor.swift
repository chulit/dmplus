import Foundation

/// Extracts downloadable links from an HTML page — the engine of the
/// Site Grabber. Pure string work: finds href/src attribute values,
/// resolves them against the page URL, keeps http(s) only, de-duplicates
/// while preserving page order.
public enum LinkExtractor {
    public struct FoundLink: Equatable, Sendable {
        public let url: URL
        public var category: FileCategory { FileCategory.classify(fileName: url.lastPathComponent) }
        public init(url: URL) { self.url = url }
    }

    public static func extract(from html: String, baseURL: URL) -> [FoundLink] {
        var seen = Set<String>()
        var result: [FoundLink] = []
        let pattern = #"(?:href|src)\s*=\s*["']([^"'#]+)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        else { return [] }
        let ns = html as NSString
        for match in regex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            let raw = ns.substring(with: match.range(at: 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty,
                  !raw.hasPrefix("javascript:"), !raw.hasPrefix("mailto:"),
                  !raw.hasPrefix("data:"),
                  let resolved = URL(string: raw, relativeTo: baseURL)?.absoluteURL,
                  let scheme = resolved.scheme,
                  scheme == "http" || scheme == "https",
                  resolved != baseURL,
                  seen.insert(resolved.absoluteString).inserted
            else { continue }
            result.append(FoundLink(url: resolved))
        }
        return result
    }

    /// Grabber filter: keep only links whose file extension is in the set
    /// (empty set = keep everything).
    public static func filter(_ links: [FoundLink], extensions: Set<String>) -> [FoundLink] {
        guard !extensions.isEmpty else { return links }
        return links.filter {
            extensions.contains($0.url.pathExtension.lowercased())
        }
    }
}
