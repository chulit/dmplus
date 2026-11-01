import Foundation
import UnduhKit

/// Owns the download list, the running tasks, and persistence.
/// Views read only what they need; all mutation happens here.
@MainActor
@Observable
final class DownloadListModel {
    var items: [DownloadItem] = []
    /// Live speeds (bytes/sec) keyed by item id; 0 when not downloading.
    var speeds: [UUID: Double] = [:]

    private let engine = DownloadEngine()
    private let store = DownloadStore(fileURL: DownloadStore.defaultFileURL())
    private let downloadsDirectory: URL
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var probes: [UUID: ProbeResult] = [:]
    private var meters: [UUID: SpeedMeter] = [:]

    init() {
        downloadsDirectory = FileManager.default.urls(
            for: .downloadsDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("UnduhQu", isDirectory: true)
        items = store.load()
    }

    func speed(for item: DownloadItem) -> Double { speeds[item.id] ?? 0 }

    // MARK: - Intents

    func add(urlString: String) {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme, ["http", "https"].contains(scheme.lowercased())
        else { return }
        let name = url.lastPathComponent.isEmpty ? (url.host ?? "download")
            : url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
        let item = DownloadItem(url: url, fileName: name)
        items.insert(item, at: 0)
        persist()
        start(item)
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

    func remove(_ item: DownloadItem) {
        tasks[item.id]?.cancel()
        tasks[item.id] = nil
        items.removeAll { $0.id == item.id }
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
            let destination = downloadsDirectory.appendingPathComponent(
                items.first(where: { $0.id == itemID })?.fileName ?? item.fileName)
            var meter = SpeedMeter()
            meters[itemID] = meter
            try await engine.download(url: item.url, to: destination, probe: probe,
                                      segmentCount: 8) { [weak self] bytes in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.update(itemID) { $0.downloadedBytes = bytes }
                    meter.record(bytes: bytes)
                    self.meters[itemID] = meter
                    self.speeds[itemID] = meter.speed()
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
