import Foundation

/// Duplicate-name handling the way IDM does it: never overwrite silently,
/// append " (1)", " (2)", ... before the extension until the name is free.
public enum FileNameResolver {
    public static func uniqueName(desired: String, existing: Set<String>) -> String {
        guard existing.contains(desired) else { return desired }
        let ns = desired as NSString
        let ext = ns.pathExtension
        let base = ns.deletingPathExtension
        var n = 1
        while true {
            let candidate = ext.isEmpty ? "\(base) (\(n))" : "\(base) (\(n)).\(ext)"
            if !existing.contains(candidate) { return candidate }
            n += 1
        }
    }
}
