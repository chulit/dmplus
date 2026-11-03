import Foundation
import DMPlusKit

/// Owns the download list, running tasks, live speeds, ETAs, speed
/// histories, and persistence. Views read only what they need.
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
    private var probes: [UUID: ProbeResult] = [:]
    private var meters: [UUID: SpeedMeter] = [:]
    private var lastSampleAt: [UUID: Date] = [:]

    init() {
        items = store.load()
    }

    // MARK: - Derived values for the table

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
        settings.downloadsFolder.appendingPathComponent(item.fileName)
    }

    var isDownloading: Bool { items.contains { $0.state == .downloading } }

    // MARK: - Intents

    func add(urlString: String, startImmediately: Bool = true) {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme, ["http", "https"].contains(scheme.lowercased())
        else { return }
        let name = url.lastPathComponent.isEmpty ? (url.host ?? "download")
            : url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
        let item = DownloadItem(url: url, fileName: name)
        items.insert(item, at: 0)
        persist()
        if startImmediately { start(item) }
    }

    func start(_ item: DownloadItem) {
        guard tasks[item.id] == nil, item.state != .completed else { return }
        setState(item.id, .downloading)
        let id = item.id
        tasks[id] = Task { [weak self] in
            await self?.run(itemID: id)
        }
    }

    func pause(_ item: DownloadItem) {
        tasks[item.id]?.cancel()
        tasks[item.id] = nil
        speeds[item.id] = 0
        setState(item.id, .paused)
        persist()
    }

    func toggle(_ item: DownloadItem) {
        switch item.state {
        case .downloading: pause(item)
        case .paused, .queued, .failed: start(item)
        case .completed: break
        }
    }

    /// IDM's "Start Queue": begin everything queued or paused.
    func startQueue() {
        for item in items where item.state == .queued || item.state == .paused {
            start(item)
        }
    }

    /// IDM's "Stop All".
    func stopAll() {
        for item in items where item.state == .downloading {
            pause(item)
        }
    }

    func remove(_ item: DownloadItem) {
        tasks[item.id]?.cancel()
        tasks[item.id] = nil
        items.removeAll { $0.id == item.id }
        speeds[item.id] = nil
        histories[item.id] = nil
        persist()
    }

    /// IDM's "Delete All Completed" (the broom button).
    func deleteCompleted() {
        items.removeAll { $0.state == .completed }
        persist()
    }

    // MARK: - Engine plumbing

    private func run(itemID: UUID) async {
        guard let item = items.first(where: { $0.id == itemID }) else { return }
        do {
            let probe: ProbeResult
            if let cached = probes[itemID] {
                probe = cached
            } else {
                probe = try await engine.probe(item.url)
                probes[itemID] = probe
            }
            update(itemID) {
                $0.totalBytes = probe.totalBytes
                if $0.fileName == item.url.lastPathComponent || $0.fileName == "download" {
                    $0.fileName = probe.suggestedFileName
                    $0.category = FileCategory.classify(fileName: probe.suggestedFileName)
                }
            }
            let current = items.first(where: { $0.id == itemID }) ?? item
            let destination = destinationURL(for: current)
            var meter = SpeedMeter()
            meters[itemID] = meter
            try await engine.download(url: item.url, to: destination, probe: probe,
                                      segmentCount: settings.maxConnections) { [weak self] bytes in
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
            speeds[itemID] = 0
            setState(itemID, .completed)
        } catch is CancellationError {
            setState(itemID, .paused)
        } catch {
            speeds[itemID] = 0
            setState(itemID, .failed(error.localizedDescription))
        }
        tasks[itemID] = nil
        persist()
    }

    private func update(_ id: UUID, _ mutate: (inout DownloadItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        mutate(&items[index])
    }

    private func setState(_ id: UUID, _ state: DownloadState) {
        update(id) { $0.state = state }
    }

    private func persist() { store.save(items) }
}
