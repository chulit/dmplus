import SwiftUI
import AppKit
import DMPlusKit

struct AddDownloadView: View {
    @Bindable var model: DownloadListModel
    @Environment(\.dismiss) private var dismiss
    @State private var urlString = ""
    @State private var customName = ""
    @State private var downloadLater = false
    @State private var batchFrom = 1
    @State private var batchTo = 10

    private var isBatch: Bool { BatchURLExpander.containsWildcard(urlString) }

    private var isValid: Bool {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme else { return false }
        return ["http", "https"].contains(scheme.lowercased()) && url.host != nil
    }

    private var batchCount: Int { max(0, batchTo - batchFrom + 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tambah URL").font(.title2).bold()
            TextField("https://contoh.com/file.zip", text: $urlString)
                .textFieldStyle(.roundedBorder)
                .frame(width: 460)
                .onSubmit { submit() }

            if isBatch {
                batchControls
            } else {
                TextField("Nama file (opsional)", text: $customName)
                    .textFieldStyle(.roundedBorder)
            }

            Toggle("Unduh nanti (masuk antrian saja)", isOn: $downloadLater)

            HStack {
                Button("Tempel dari Clipboard") {
                    if let text = NSPasteboard.general.string(forType: .string) {
                        urlString = text
                    }
                }
                Spacer()
                Button("Batal") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(submitTitle) { submit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid || (isBatch && batchCount == 0))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }

    private var batchControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Unduhan batch: `*` akan diganti angka berurutan (seperti batch download IDM).")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Text("Dari")
                TextField("", value: $batchFrom, format: .number)
                    .frame(width: 60)
                Text("sampai")
                TextField("", value: $batchTo, format: .number)
                    .frame(width: 60)
                Text("= \(batchCount) file")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var submitTitle: String {
        if isBatch { return downloadLater ? "Antrian \(batchCount) File" : "Unduh \(batchCount) File" }
        return downloadLater ? "Tambah ke Antrian" : "Unduh Sekarang"
    }

    private func submit() {
        guard isValid else { return }
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if isBatch {
            guard batchTo >= batchFrom else { return }
            for url in BatchURLExpander.expand(trimmed, range: batchFrom...batchTo) {
                model.add(url: url, startImmediately: !downloadLater)
            }
        } else if let url = URL(string: trimmed) {
            model.add(url: url,
                      fileName: customName.isEmpty ? nil : customName,
                      startImmediately: !downloadLater)
        }
        dismiss()
    }
}
