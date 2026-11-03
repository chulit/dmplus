import SwiftUI
import AppKit
import DMPlusKit

/// Per-download progress window: big progress bar, live statistics and
/// the speed graph — modelled on IDM's download progress dialog, drawn
/// with native macOS controls.
struct DownloadDetailView: View {
    @Bindable var model: DownloadListModel
    let itemID: UUID
    @Environment(\.dismiss) private var dismiss

    private var item: DownloadItem? {
        model.items.first { $0.id == itemID }
    }

    var body: some View {
        Group {
            if let item {
                content(for: item)
            } else {
                ContentUnavailableView("Unduhan sudah dihapus", systemImage: "trash")
            }
        }
        .frame(width: 520)
        .padding(20)
    }

    private func content(for item: DownloadItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: item.category.symbolName)
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.fileName).font(.title3).bold().lineLimit(1)
                    Text(item.url.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }

            if item.state == .completed {
                ProgressView(value: 1.0).tint(.green)
            } else if let fraction = item.progressFraction {
                ProgressView(value: fraction)
            } else {
                ProgressView().progressViewStyle(.linear)
            }

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                statRow("Status", statusText(for: item))
                statRow("Ukuran file", item.totalBytes.map(ByteFormat.format) ?? "—")
                statRow("Terunduh", ByteFormat.formatProgress(
                    downloaded: item.downloadedBytes, total: item.totalBytes))
                statRow("Kecepatan", item.state == .downloading
                        ? ByteFormat.formatSpeed(model.speed(for: item)) : "—")
                statRow("Sisa waktu", ETACalculator.format(model.eta(for: item)))
                statRow("Kategori", item.category.rawValue.capitalized)
            }
            .font(.callout)

            VStack(alignment: .leading, spacing: 4) {
                Text("Grafik kecepatan")
                    .font(.caption).foregroundStyle(.secondary)
                SpeedGraphView(history: model.history(for: item))
                    .frame(height: 70)
            }

            HStack {
                if item.state == .completed {
                    Button("Tampilkan di Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting(
                            [model.destinationURL(for: item)])
                    }
                } else {
                    Button(item.state == .downloading ? "Jeda" : "Lanjutkan") {
                        model.toggle(item)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button("Hapus dari Daftar", role: .destructive) {
                    model.remove(item)
                    dismiss()
                }
                Spacer()
                Button("Tutup") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value)
        }
    }

    private func statusText(for item: DownloadItem) -> String {
        switch item.state {
        case .queued: return "Dalam antrian"
        case .downloading:
            if let fraction = item.progressFraction {
                return "Mengunduh — \(Int(fraction * 100))%"
            }
            return "Mengunduh"
        case .paused: return "Jeda"
        case .completed: return "Selesai"
        case .failed(let reason): return "Gagal: \(reason)"
        }
    }
}
