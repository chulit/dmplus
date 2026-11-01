import Foundation

/// JSON persistence for the download list (~/Library/Application Support/UnduhQu/downloads.json by default).
public final class DownloadStore: @unchecked Sendable {
    private let fileURL: URL
    private let lock = NSLock()

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("UnduhQu/downloads.json")
    }

    public func load() -> [DownloadItem] {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? Data(contentsOf: fileURL),
              let items = try? JSONDecoder().decode([DownloadItem].self, from: data)
        else { return [] }
        // Anything that was mid-download when the app died comes back paused.
        return items.map { item in
            var item = item
            if item.state == .downloading { item.state = .paused }
            return item
        }
    }

    public func save(_ items: [DownloadItem]) {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
