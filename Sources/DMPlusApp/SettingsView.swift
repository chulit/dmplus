import SwiftUI
import AppKit

/// Options dialog: the IDM Options + Scheduler screens, combined.
struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Unduhan") {
                Stepper(value: $settings.maxConnections, in: 1...16) {
                    Text("Koneksi per unduhan: \(settings.maxConnections)")
                }
                Stepper(value: $settings.maxSimultaneous, in: 1...10) {
                    Text("Unduhan bersamaan maks: \(settings.maxSimultaneous)")
                }
                Stepper(value: $settings.retryAttempts, in: 0...10) {
                    Text("Coba lagi otomatis saat gagal: \(settings.retryAttempts)×")
                }
                HStack {
                    Text("Batas kecepatan")
                    Spacer()
                    TextField("KB/s", value: $settings.speedLimitKBps, format: .number)
                        .frame(width: 70)
                        .multilineTextAlignment(.trailing)
                    Text("KB/s (0 = tanpa batas)")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Folder Tujuan") {
                LabeledContent("Folder") {
                    HStack {
                        Text(settings.downloadsFolder.path)
                            .lineLimit(1).truncationMode(.head)
                            .textSelection(.enabled)
                        Button("Pilih…") { chooseFolder() }
                    }
                }
                Toggle("Simpan ke subfolder per kategori (Video, Music, Documents, …)",
                       isOn: $settings.categorySubfolders)
            }

            Section("Integrasi") {
                Toggle("Pantau clipboard — URL yang disalin otomatis diunduh",
                       isOn: $settings.monitorClipboard)
                Text("Integrasi browser berjalan lewat ekstensi DM+ dan DMPlusMsgHost (folder Extensions di repo); URL dari browser masuk otomatis ke daftar.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Setelah Selesai") {
                Toggle("Tampilkan notifikasi", isOn: $settings.notifyOnComplete)
                Toggle("Bunyikan suara", isOn: $settings.soundOnComplete)
                TextField("Program pemeriksa (opsional, mis. antivirus) — dijalankan dengan file sebagai argumen",
                          text: $settings.postDownloadCommand)
                    .font(.callout)
            }

            Section("Penjadwal") {
                Toggle("Aktifkan penjadwal antrian", isOn: $settings.schedulerEnabled)
                DatePicker("Mulai antrian pukul",
                           selection: minutesBinding($settings.schedulerStartMinutes),
                           displayedComponents: .hourAndMinute)
                DatePicker("Hentikan antrian pukul",
                           selection: minutesBinding($settings.schedulerStopMinutes),
                           displayedComponents: .hourAndMinute)
                Text("Di luar jam tersebut antrian yang dimulai penjadwal akan dihentikan. Jendela melewati tengah malam didukung.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 560)
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

    private func minutesBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: minutes.wrappedValue / 60,
                                      minute: minutes.wrappedValue % 60,
                                      second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                minutes.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            })
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
