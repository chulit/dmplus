import SwiftUI
import AppKit

/// Options dialog: connections per download + destination folder.
struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Stepper(value: $settings.maxConnections, in: 1...16) {
                Text("Koneksi per unduhan: \(settings.maxConnections)")
            }
            Text("Lebih banyak koneksi = file dipecah lebih kecil, seperti pengaturan koneksi di IDM. Berlaku untuk unduhan yang dimulai setelah ini.")
                .font(.caption).foregroundStyle(.secondary)

            LabeledContent("Folder tujuan") {
                HStack {
                    Text(settings.downloadsFolder.path)
                        .lineLimit(1).truncationMode(.head)
                        .textSelection(.enabled)
                    Button("Pilih…") { chooseFolder() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Text("Pengaturan DM+").font(.headline)
                Spacer()
                Button("Selesai") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(12)
            .background(.bar)
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = settings.downloadsFolder
        if panel.runModal() == .OK, let url = panel.url {
            settings.downloadsFolder = url
        }
    }
}
