import SwiftUI
import UnduhKit

/// One row in the list. Receives plain values only, so progress updates
/// invalidate just this row, not the whole screen.
struct DownloadRowView: View {
    let item: DownloadItem
    let speed: Double
    let onToggle: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.category.symbolName)
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.fileName)
                    .font(.headline)
                    .lineLimit(1)
                progressView
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if item.state != .completed {
                Button(action: onToggle) {
                    Image(systemName: item.state == .downloading ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(item.state == .downloading ? "Jeda" : "Lanjutkan")
            }
            Button(role: .destructive, action: onRemove) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Hapus dari daftar")
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var progressView: some View {
        if item.state == .completed {
            ProgressView(value: 1.0)
                .tint(.green)
        } else if let fraction = item.progressFraction {
            ProgressView(value: fraction)
        } else if item.state == .downloading {
            ProgressView()
                .progressViewStyle(.linear)
        } else {
            ProgressView(value: 0)
        }
    }

    private var statusText: String {
        switch item.state {
        case .completed:
            return "Selesai • \(ByteFormat.format(item.downloadedBytes))"
        case .failed(let reason):
            return "Gagal: \(reason)"
        case .paused:
            return "Jeda • \(ByteFormat.formatProgress(downloaded: item.downloadedBytes, total: item.totalBytes))"
        case .queued:
            return "Menunggu…"
        case .downloading:
            let progress = ByteFormat.formatProgress(downloaded: item.downloadedBytes, total: item.totalBytes)
            if speed > 0 {
                return "\(progress) • \(ByteFormat.formatSpeed(speed))"
            }
            return progress
        }
    }
}
