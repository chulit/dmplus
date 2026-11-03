import Foundation

/// User preferences — DM+'s version of IDM's Options dialog.
/// UserDefaults-backed; every value applies to downloads started after it changes.
@MainActor
@Observable
final class AppSettings {
    // Unduhan
    var maxConnections: Int { didSet { defaults.set(maxConnections, forKey: "dmplus.maxConnections") } }
    /// KB/s, 0 = unlimited (IDM's speed limiter).
    var speedLimitKBps: Int { didSet { defaults.set(speedLimitKBps, forKey: "dmplus.speedLimitKBps") } }
    var maxSimultaneous: Int { didSet { defaults.set(maxSimultaneous, forKey: "dmplus.maxSimultaneous") } }
    var retryAttempts: Int { didSet { defaults.set(retryAttempts, forKey: "dmplus.retryAttempts") } }
    var downloadsFolder: URL { didSet { defaults.set(downloadsFolder.path, forKey: "dmplus.downloadsFolder") } }
    var categorySubfolders: Bool { didSet { defaults.set(categorySubfolders, forKey: "dmplus.categorySubfolders") } }

    // Integrasi
    var monitorClipboard: Bool { didSet { defaults.set(monitorClipboard, forKey: "dmplus.monitorClipboard") } }

    // Selesai
    var notifyOnComplete: Bool { didSet { defaults.set(notifyOnComplete, forKey: "dmplus.notifyOnComplete") } }
    var soundOnComplete: Bool { didSet { defaults.set(soundOnComplete, forKey: "dmplus.soundOnComplete") } }
    /// Executable run with the finished file as its argument (IDM's virus-checker field). Empty = off.
    var postDownloadCommand: String { didSet { defaults.set(postDownloadCommand, forKey: "dmplus.postDownloadCommand") } }

    // Penjadwal (IDM Scheduler): start/stop the queue at set times of day.
    var schedulerEnabled: Bool { didSet { defaults.set(schedulerEnabled, forKey: "dmplus.schedulerEnabled") } }
    var schedulerStartMinutes: Int { didSet { defaults.set(schedulerStartMinutes, forKey: "dmplus.schedulerStart") } }
    var schedulerStopMinutes: Int { didSet { defaults.set(schedulerStopMinutes, forKey: "dmplus.schedulerStop") } }

    private let defaults = UserDefaults.standard

    var speedLimitBytesPerSecond: Int64 {
        speedLimitKBps <= 0 ? 0 : Int64(speedLimitKBps) * 1024
    }

    init() {
        let d = UserDefaults.standard
        maxConnections = d.integer(forKey: "dmplus.maxConnections") == 0
            ? 8 : min(16, max(1, d.integer(forKey: "dmplus.maxConnections")))
        speedLimitKBps = max(0, d.integer(forKey: "dmplus.speedLimitKBps"))
        maxSimultaneous = d.integer(forKey: "dmplus.maxSimultaneous") == 0
            ? 3 : min(10, max(1, d.integer(forKey: "dmplus.maxSimultaneous")))
        retryAttempts = d.object(forKey: "dmplus.retryAttempts") == nil
            ? 3 : min(10, max(0, d.integer(forKey: "dmplus.retryAttempts")))
        if let path = d.string(forKey: "dmplus.downloadsFolder") {
            downloadsFolder = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            downloadsFolder = FileManager.default.urls(
                for: .downloadsDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("DMPlus", isDirectory: true)
        }
        categorySubfolders = d.bool(forKey: "dmplus.categorySubfolders")
        monitorClipboard = d.bool(forKey: "dmplus.monitorClipboard")
        notifyOnComplete = d.object(forKey: "dmplus.notifyOnComplete") == nil
            ? true : d.bool(forKey: "dmplus.notifyOnComplete")
        soundOnComplete = d.object(forKey: "dmplus.soundOnComplete") == nil
            ? true : d.bool(forKey: "dmplus.soundOnComplete")
        postDownloadCommand = d.string(forKey: "dmplus.postDownloadCommand") ?? ""
        schedulerEnabled = d.bool(forKey: "dmplus.schedulerEnabled")
        schedulerStartMinutes = d.object(forKey: "dmplus.schedulerStart") == nil
            ? 0 : d.integer(forKey: "dmplus.schedulerStart")
        schedulerStopMinutes = d.object(forKey: "dmplus.schedulerStop") == nil
            ? 360 : d.integer(forKey: "dmplus.schedulerStop")
    }
}
