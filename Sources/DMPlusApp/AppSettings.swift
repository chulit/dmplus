import Foundation

/// User preferences (the IDM "Options" dialog, reduced to what DM+ supports):
/// connections per download and the destination folder. UserDefaults-backed.
@MainActor
@Observable
final class AppSettings {
    var maxConnections: Int {
        didSet { UserDefaults.standard.set(maxConnections, forKey: Self.connectionsKey) }
    }
    var downloadsFolder: URL {
        didSet { UserDefaults.standard.set(downloadsFolder.path, forKey: Self.folderKey) }
    }

    private static let connectionsKey = "dmplus.maxConnections"
    private static let folderKey = "dmplus.downloadsFolder"

    init() {
        let stored = UserDefaults.standard.integer(forKey: Self.connectionsKey)
        maxConnections = stored == 0 ? 8 : min(16, max(1, stored))
        if let path = UserDefaults.standard.string(forKey: Self.folderKey) {
            downloadsFolder = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            downloadsFolder = FileManager.default.urls(
                for: .downloadsDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("DMPlus", isDirectory: true)
        }
    }
}
