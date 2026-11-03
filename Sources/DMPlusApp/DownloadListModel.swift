import Foundation
import AppKit
import UserNotifications
import DMPlusKit

/// Owns the download list, the queue pump (max simultaneous downloads),
/// auto-retry, the time scheduler, the clipboard monitor, the browser
/// extension inbox, and persistence — DM+'s equivalent of IDM's engine room.
@MainActor
@Observable
final class DownloadListModel {
    var items: [DownloadItem] = []
    var speeds: [UUID: Double] = [:]
    var histories: [UUID: SpeedHistory] = [:]

    let settings = AppSettings()

    private let engine = DownloadEngine()
    private let store = DownloadStore(fileURL: DownloadStore.defaultFileURL())
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var wantsRunning: Set<UUID> = []
    private var probes: [UUID: ProbeResult] = [:]
    private var meters: [UUID: SpeedMeter] = [:]
    private var lastSampleAt: [UUID: Date] = [:]
    private var schedulerStartedQueue = false
    private var lastClipboardChange = NSPasteboard.general.changeCount
    private var timers: [Timer] = []

    init() {
        items = store.load()
        startBackgroundServices()
    }

    // MARK: - Derived values

    func speed(for item: DownloadItem) -> Double { speeds[item.id] ?? 0 }

    func eta(for item: DownloadItem) -> TimeInterval? {
        guard item.state == .downloading else { return nil }
        return ETACalculator.remainingSeconds(
            totalBytes: item.totalBytes, downloadedBytes: item.downloadedBytes,
            bytesPerSecond: speed(for: item))
    }

    func history(for item: DownloadItem) -> SpeedHistory {
        histories[item.id] ?? SpeedHistory()
    }

    func destinationURL(for item: DownloadItem) -> URL {
        var folder = settings.downloadsFolder
        if settings.categorySubfolders {
            folder = folder.appendingPathComponent(item.category.folderName, isDirectory: true)
        }
        return folder.appendingPathComponent(item.fileName)
    }

    var isDownloading: Bool { items.contains { $0.state == .downloading } }
    private var runningCount: Int { tasks.count }

    // MARK: - Adding

    func add(urlString: String, startImmediately: Bool = true) {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme, ["http", "https"].contains(scheme.lowercased())
        else { return }
        add(url: url, startImmediately: startImmediately)
    }

    func add(url: URL, fileName customName: String? = nil, startImmediately: Bool = true) {
        // IDM warns about duplicates; DM+ just focuses the existing entry.
        if let existing = items.first(where: { $0.url == url && $0.state != .completed }) {
            if startImmediately { start(existing) }
            return
        }
        let name = customName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fileName = (name?.isEmpty == false ? name! :
            (url.lastPathComponent.isEmpty ? (url.host ?? "download")
             : url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent))
        let item = DownloadItem(url: url, fileName: fileName)
        items.insert(item, at: 0)
        persist()
        if startImmediately { start(item) }
    }

    // MARK: - Queue pump

    func start(_ item: DownloadItem) {
        guard item.state != .completed else { return }
        wantsRunning.insert(item.id)
        pumpQueue()
    }

    func pause(_ item: DownloadItem) {
        wantsRunning.remove(item.id)
        tasks[item.id]?.cancel()
        tasks[item.id] = nil
        speeds[item.id] = 0
        if item.state == .downloading || item.state == .queued {
            setState(item.id, .paused)
        }
        persist()
        pumpQueue()
    }

    func toggle(_ item: DownloadItem) {
        switch item.state {
        case .downloading, .queued:
            if wantsRunning.contains(item.id) { pause(item) } else { start(item) }
        case .paused, .failed: start(item)
        case .completed: break
        }
    }

    func startQueue() {
        for item in items where item.state == .queued || item.state == .paused {
            wantsRunning.insert(item.id)
        }
        pumpQueue()
    }

    func stopAll() {
        wantsRunning.removeAll()
        for item in items where item.state == .downloading || item.state == .queued {
            tasks[item.id]?.cancel()
            tasks[item.id] = nil
            speeds[item.id] = 0
            setState(item.id, .paused)
        }
        persist()
    }

    func remove(_ item: DownloadItem) {
        wantsRunning.remove(item.id)
        tasks[item.id]?.cancel()
        tasks[item.id] = nil
        items.removeAll { $0.id == item.id }
        speeds[item.id] = nil
        histories[item.id] = nil
        persist()
        pumpQueue()
    }

    func deleteCompleted() {
        items.removeAll { $0.state == .completed }
        persist()
    }

    /// Starts queued downloads (in list order) up to the simultaneous cap.
    private func pumpQueue() {
        for item in items {
            guard runningCount < settings.maxSimultaneous else { return }
            guard wantsRunning.contains(item.id),
                  tasks[item.id] == nil,
                  item.state == .queued || item.state == .paused || item.state == .failed
            else { continue }
            setState(item.id, .downloading)
            let id = item.id
            tasks[id] = Task { [weak self] in
                await self?.run(itemID: id)
            }
        }
        // Anything wanting to run but waiting for a slot reads as queued.
        for item in items where wantsRunning.contains(item.id)
            && tasks[item.id] == nil && item.state == .paused {
            setState(item.id, .queued)
        }
    }

    // MARK: - Engine run (with auto-retry)

    private func run(itemID: UUID) async {
        guard let item = items.first(where: { $0.id == itemID }) else { return }
        let policy = RetryPolicy(maxAttempts: settings.retryAttempts)
        var attempt = 0
        while true {
            attempt += 1
            do {
                try await performDownload(itemID: itemID)
                speeds[itemID] = 0
                setState(itemID, .completed)
                wantsRunning.remove(itemID)
                onCompleted(itemID: itemID)
                break
            } catch is CancellationError {
                if wantsRunning.contains(itemID) { setState(itemID, .queued) }
                else { setState(itemID, .paused) }
                break
            } catch {
                if let delay = policy.delay(forAttempt: attempt) {
                    speeds[itemID] = 0
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    if Task.isCancelled { setState(itemID, .paused); break }
                    continue
                }
                speeds[itemID] = 0
                wantsRunning.remove(itemID)
                setState(itemID, .failed(error.localizedDescription))
                break
            }
        }
        tasks[itemID] = nil
        persist()
        pumpQueue()
    }

    private func performDownload(itemID: UUID) async throws {
        guard let item = items.first(where: { $0.id == itemID }) else { return }
        let probe: ProbeResult
        if let cached = probes[itemID] {
            probe = cached
        } else {
            probe = try await engine.probe(item.url)
            probes[itemID] = probe
        }
        update(itemID) {
            $0.totalBytes = probe.totalBytes
            if $0.downloadedBytes == 0,
               $0.fileName == item.url.lastPathComponent || $0.fileName == "download" {
                $0.fileName = probe.suggestedFileName
                $0.category = FileCategory.classify(fileName: probe.suggestedFileName)
            }
        }
        // Never overwrite a finished file silently: rename like IDM does.
        if item.downloadedBytes == 0 {
            let folder = destinationURL(for: items.first(where: { $0.id == itemID }) ?? item)
                .deletingLastPathComponent()
            let existing = Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
            let current = items.first(where: { $0.id == itemID }) ?? item
            let unique = FileNameResolver.uniqueName(desired: current.fileName, existing: existing)
            if unique != current.fileName { update(itemID) { $0.fileName = unique } }
        }
        let current = items.first(where: { $0.id == itemID }) ?? item
        let destination = destinationURL(for: current)
        var meter = SpeedMeter()
        meters[itemID] = meter
        try await engine.download(url: item.url, to: destination, probe: probe,
                                  segmentCount: settings.maxConnections,
                                  speedLimitBytesPerSecond: settings.speedLimitBytesPerSecond
        ) { [weak self] bytes in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.update(itemID) { $0.downloadedBytes = bytes }
                meter.record(bytes: bytes)
                self.meters[itemID] = meter
                let speed = meter.speed()
                self.speeds[itemID] = speed
                let now = Date()
                if now.timeIntervalSince(self.lastSampleAt[itemID] ?? .distantPast) >= 0.5 {
                    self.lastSampleAt[itemID] = now
                    var history = self.histories[itemID] ?? SpeedHistory()
                    history.append(speed)
                    self.histories[itemID] = history
                }
            }
        }
    }

    private func onCompleted(itemID: UUID) {
        guard let item = items.first(where: { $0.id == itemID }) else { return }
        if settings.soundOnComplete {
            NSSound(named: NSSound.Name("Glass"))?.play()
        }
        if settings.notifyOnComplete, Bundle.main.bundleIdentifier != nil {
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
            let content = UNMutableNotificationContent()
            content.title = "Unduhan selesai"
            content.body = item.fileName
            center.add(UNNotificationRequest(
                identifier: itemID.uuidString, content: content, trigger: nil))
        }
        let command = settings.postDownloadCommand
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !command.isEmpty, FileManager.default.isExecutableFile(atPath: command) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: command)
            process.arguments = [destinationURL(for: item).path]
            try? process.run()
        }
    }

    // MARK: - Background services: scheduler, clipboard, extension inbox

    private func startBackgroundServices() {
        let scheduler = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.schedulerTick() }
        }
        let clipboard = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.clipboardTick() }
        }
        let inbox = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.inboxTick() }
        }
        timers = [scheduler, clipboard, inbox]
    }

    private func schedulerTick() {
        guard settings.schedulerEnabled else {
            schedulerStartedQueue = false
            return
        }
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let minutes = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        let start = settings.schedulerStartMinutes
        let stop = settings.schedulerStopMinutes
        let inside = start <= stop
            ? (minutes >= start && minutes < stop)
            : (minutes >= start || minutes < stop)
        if inside, !schedulerStartedQueue {
            schedulerStartedQueue = true
            startQueue()
        } else if !inside, schedulerStartedQueue {
            schedulerStartedQueue = false
            stopAll()
        }
    }

    private func clipboardTick() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastClipboardChange else { return }
        lastClipboardChange = pasteboard.changeCount
        guard settings.monitorClipboard,
              let text = pasteboard.string(forType: .string)
        else { return }
        add(urlString: text, startImmediately: true)
    }

    /// URLs sent by the browser extension via DMPlusMsgHost land in
    /// Application Support/DMPlus/inbox.jsonl, one JSON object per line.
    private func inboxTick() {
        let inboxURL = DownloadStore.defaultFileURL()
            .deletingLastPathComponent().appendingPathComponent("inbox.jsonl")
        guard let data = try? Data(contentsOf: inboxURL), !data.isEmpty,
              let text = String(data: data, encoding: .utf8) else { return }
        try? FileManager.default.removeItem(at: inboxURL)
        for line in text.split(separator: "\n") {
            guard let lineData = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let urlString = object["url"] as? String
            else { continue }
            add(urlString: urlString, startImmediately: true)
        }
    }

    // MARK: - Import / export (IDM's .ef2 equivalent, as JSON)

    func exportItems(to url: URL) throws {
        let data = try JSONEncoder().encode(items)
        try data.write(to: url, options: .atomic)
    }

    func importItems(from url: URL) {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([DownloadItem].self, from: data)
        else { return }
        for var item in decoded where !items.contains(where: { $0.url == item.url }) {
            if item.state == .downloading { item.state = .paused }
            items.append(item)
        }
        persist()
    }

    // MARK: - Helpers

    private func update(_ id: UUID, _ mutate: (inout DownloadItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        mutate(&items[index])
    }

    private func setState(_ id: UUID, _ state: DownloadState) {
        update(id) { $0.state = state }
    }

    private func persist() { store.save(items) }
}

extension FileCategory {
    /// Subfolder name used when "category subfolders" is on.
    var folderName: String {
        switch self {
        case .video: return "Video"
        case .audio: return "Music"
        case .image: return "Pictures"
        case .document: return "Documents"
        case .archive: return "Compressed"
        case .application: return "Programs"
        case .other: return "Other"
        }
    }
}
