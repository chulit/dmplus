import Foundation

/// State of one download. `failed` carries the user-visible reason.
public enum DownloadState: Codable, Equatable, Sendable {
    case queued
    case downloading
    case paused
    case completed
    case failed(String)
}

/// One download in the list. Persisted by `DownloadStore` so a download
/// survives an app relaunch (resume is a first-class feature, like IDM).
public struct DownloadItem: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var url: URL
    public var fileName: String
    /// Total size in bytes when the server reported one; `nil` means unknown
    /// and the UI must render "—" instead of inventing a number.
    public var totalBytes: Int64?
    public var downloadedBytes: Int64
    public var state: DownloadState
    public var category: FileCategory
    public var createdAt: Date
    /// Browser session forwarded by the extension: sites that only serve
    /// the file to the session that clicked need these, or the app gets
    /// an HTML page back instead of the file.
    public var cookie: String?
    public var referer: String?

    public init(id: UUID = UUID(), url: URL, fileName: String,
                totalBytes: Int64? = nil, downloadedBytes: Int64 = 0,
                state: DownloadState = .queued, createdAt: Date = Date(),
                cookie: String? = nil, referer: String? = nil) {
        self.id = id
        self.url = url
        self.fileName = fileName
        self.totalBytes = totalBytes
        self.downloadedBytes = downloadedBytes
        self.state = state
        self.category = FileCategory.classify(fileName: fileName)
        self.createdAt = createdAt
        self.cookie = cookie
        self.referer = referer
    }

    /// 0...1 when the total is known, `nil` when it is not.
    public var progressFraction: Double? {
        guard let totalBytes, totalBytes > 0 else { return nil }
        return min(1.0, Double(downloadedBytes) / Double(totalBytes))
    }
}
