import SwiftUI
import AppKit
import DMPlusKit
import UniformTypeIdentifiers

/// Sidebar filter, mirroring IDM's Categories tree: the three status
/// groups plus one entry per file category.
enum SidebarSelection: Hashable {
    case all
    case unfinished
    case finished
    case category(FileCategory)
}

struct ContentView: View {
    @Bindable var model: DownloadListModel
    @State private var sidebar: SidebarSelection? = .all
    @State private var selection: DownloadItem.ID?
    @State private var detailID: DownloadItem.ID?
    @State private var showingAdd = false
    @State private var showingSettings = false
    @State private var showingGrabber = false
    @State private var panelController = FloatingPanelController()

    private var filteredItems: [DownloadItem] {
        switch sidebar ?? .all {
        case .all: return model.items
        case .unfinished: return model.items.filter { $0.state != .completed }
        case .finished: return model.items.filter { $0.state == .completed }
        case .category(let category): return model.items.filter { $0.category == category }
        }
    }

    private var selectedItem: DownloadItem? {
        model.items.first { $0.id == selection }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $sidebar) {
                Section("Unduhan") {
                    Label("Semua Unduhan", systemImage: "tray.full")
                        .tag(SidebarSelection.all)
                    Label("Belum Selesai", systemImage: "clock")
                        .tag(SidebarSelection.unfinished)
                    Label("Selesai", systemImage: "checkmark.circle")
                        .tag(SidebarSelection.finished)
                }
                Section("Kategori") {
                    ForEach(FileCategory.allCases.filter { $0 != .other }, id: \.self) { category in
                        Label(category.displayName, systemImage: category.symbolName)
                            .tag(SidebarSelection.category(category))
                    }
                    Label(FileCategory.other.displayName, systemImage: FileCategory.other.symbolName)
                        .tag(SidebarSelection.category(.other))
                }
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 200)
        } detail: {
            detailTable
        }
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingAdd) {
            AddDownloadView(model: model)
        }
        .sheet(isPresented: $showingGrabber) {
            GrabberView(model: model)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(settings: model.settings)
        }
        .sheet(item: detailBinding) { item in
            DownloadDetailView(model: model, itemID: item.id)
        }
    }

    // MARK: - Table (the IDM list)

    private var detailTable: some View {
        Group {
            if filteredItems.isEmpty {
                ContentUnavailableView {
                    Label("Tidak ada unduhan", systemImage: "arrow.down.circle")
                } description: {
                    Text("Tambahkan URL lewat tombol + di toolbar.\nFile besar otomatis dipecah ke beberapa koneksi.")
                }
            } else {
                Table(filteredItems, selection: $selection) {
                    TableColumn("Nama File") { item in
                        HStack(spacing: 6) {
                            Image(systemName: item.category.symbolName)
                                .foregroundStyle(.secondary)
                            Text(item.fileName).lineLimit(1)
                        }
                    }
                    .width(min: 220, ideal: 340)

                    TableColumn("Ukuran") { item in
                        Text(item.totalBytes.map(ByteFormat.format) ?? "—")
                            .foregroundStyle(.secondary)
                    }
                    .width(84)

                    TableColumn("Status") { item in
                        Text(statusText(for: item))
                    }
                    .width(min: 110, ideal: 150)

                    TableColumn("Progres") { item in
                        progressCell(for: item)
                    }
                    .width(110)

                    TableColumn("Sisa Waktu") { item in
                        Text(ETACalculator.format(model.eta(for: item)))
                            .foregroundStyle(.secondary)
                    }
                    .width(84)

                    TableColumn("Kecepatan") { item in
                        Text(item.state == .downloading
                             ? ByteFormat.formatSpeed(model.speed(for: item)) : "—")
                            .foregroundStyle(.secondary)
                    }
                    .width(84)

                    TableColumn("Tanggal") { item in
                        Text(item.createdAt, format: .dateTime.day().month().year().hour().minute())
                            .foregroundStyle(.secondary)
                    }
                    .width(130)
                }
                .contextMenu(forSelectionType: DownloadItem.ID.self) { ids in
                    if let item = model.items.first(where: { ids.contains($0.id) }) {
                        Button(item.state == .downloading ? "Jeda" : "Lanjutkan") {
                            model.toggle(item)
                        }
                        Button("Detail…") { detailID = item.id }
                        Divider()
                        Button("Hapus dari Daftar", role: .destructive) {
                            model.remove(item)
                        }
                    }
                } primaryAction: { ids in
                    detailID = ids.first
                }
            }
        }
        .onDrop(of: [.text, .url], isTargeted: nil) { providers in
            for provider in providers {
                provider.loadObject(ofClass: NSString.self) { object, _ in
                    if let text = object as? String {
                        Task { @MainActor in model.add(urlString: text) }
                    }
                }
            }
            return true
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Text("\(model.items.count) unduhan • \(model.items.filter { $0.state == .completed }.count) selesai")
                Spacer()
                Text("Klik dua kali baris untuk detail & grafik kecepatan")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)
        }
    }

    @ViewBuilder
    private func progressCell(for item: DownloadItem) -> some View {
        if item.state == .completed {
            ProgressView(value: 1.0).tint(.green)
        } else if let fraction = item.progressFraction {
            ProgressView(value: fraction)
        } else if item.state == .downloading {
            ProgressView().progressViewStyle(.linear)
        } else {
            ProgressView(value: 0)
        }
    }

    private func statusText(for item: DownloadItem) -> String {
        switch item.state {
        case .queued: return "Dalam antrian"
        case .downloading:
            if let fraction = item.progressFraction {
                return "Mengunduh \(Int(fraction * 100))%"
            }
            return "Mengunduh"
        case .paused: return "Jeda"
        case .completed: return "Selesai"
        case .failed: return "Gagal"
        }
    }

    // MARK: - Toolbar (the IDM buttons)

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button { showingAdd = true } label: {
                Label("Tambah URL", systemImage: "plus.circle")
            }
            .keyboardShortcut("n", modifiers: .command)
            .help("Tambah URL (⌘N)")

            Button {
                if let selectedItem { model.start(selectedItem) }
            } label: {
                Label("Lanjutkan", systemImage: "play.circle")
            }
            .disabled(selectedItem == nil || selectedItem?.state == .downloading
                      || selectedItem?.state == .completed)
            .help("Lanjutkan unduhan terpilih")

            Button {
                if let selectedItem { model.pause(selectedItem) }
            } label: {
                Label("Stop", systemImage: "pause.circle")
            }
            .disabled(selectedItem?.state != .downloading)
            .help("Jeda unduhan terpilih")

            Button { model.startQueue() } label: {
                Label("Mulai Antrian", systemImage: "play.circle.fill")
            }
            .help("Mulai semua unduhan yang jeda/antri")

            Button { model.stopAll() } label: {
                Label("Stop Semua", systemImage: "stop.circle")
            }
            .disabled(!model.isDownloading)
            .help("Jeda semua unduhan yang berjalan")

            Button {
                if let selectedItem { model.remove(selectedItem) }
            } label: {
                Label("Hapus", systemImage: "trash")
            }
            .disabled(selectedItem == nil)
            .help("Hapus unduhan terpilih dari daftar")

            Button { model.deleteCompleted() } label: {
                Label("Hapus Selesai", systemImage: "trash.slash")
            }
            .disabled(!model.items.contains { $0.state == .completed })
            .help("Hapus semua yang selesai dari daftar")

            Button { showingSettings = true } label: {
                Label("Pengaturan", systemImage: "gearshape")
            }
            .help("Pengaturan koneksi & folder tujuan")

            Menu {
                Button("Site Grabber…") { showingGrabber = true }
                Button("Panel Apung (Drop Target)") { panelController.toggle(model: model) }
                Divider()
                Button("Ekspor Daftar…") { exportList() }
                Button("Impor Daftar…") { importList() }
            } label: {
                Label("Lainnya", systemImage: "ellipsis.circle")
            }
            .help("Grabber, panel apung, impor/ekspor daftar")
        }
    }

    private func exportList() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "dmplus-daftar-unduhan.json"
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            try? model.exportItems(to: url)
        }
    }

    private func importList() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            model.importItems(from: url)
        }
    }

    private var detailBinding: Binding<DownloadItem?> {
        Binding(
            get: { model.items.first { $0.id == detailID } },
            set: { detailID = $0?.id })
    }
}

extension FileCategory {
    var displayName: String {
        switch self {
        case .video: return "Video"
        case .audio: return "Musik"
        case .image: return "Gambar"
        case .document: return "Dokumen"
        case .archive: return "Arsip"
        case .application: return "Program"
        case .other: return "Lainnya"
        }
    }
}
