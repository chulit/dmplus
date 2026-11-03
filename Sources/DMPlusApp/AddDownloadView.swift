import SwiftUI
import AppKit

struct AddDownloadView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlString = ""
    @State private var downloadLater = false
    let onAdd: (String, Bool) -> Void

    private var isValid: Bool {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme else { return false }
        return ["http", "https"].contains(scheme.lowercased()) && url.host != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tambah URL")
                .font(.title2).bold()
            TextField("https://contoh.com/file.zip", text: $urlString)
                .textFieldStyle(.roundedBorder)
                .frame(width: 460)
                .onSubmit { submit() }
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
                Button(downloadLater ? "Tambah ke Antrian" : "Unduh Sekarang") { submit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }

    private func submit() {
        guard isValid else { return }
        onAdd(urlString, !downloadLater)
        dismiss()
    }
}
