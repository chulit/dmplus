import SwiftUI
import UnduhKit

struct ContentView: View {
    @Bindable var model: DownloadListModel
    @State private var showingAdd = false

    var body: some View {
        Group {
            if model.items.isEmpty {
                ContentUnavailableView {
                    Label("Belum ada unduhan", systemImage: "arrow.down.circle")
                } description: {
                    Text("Tambahkan URL untuk mulai mengunduh.\nFile besar akan dipecah ke beberapa koneksi agar lebih cepat.")
                } actions: {
                    Button("Tambah Unduhan") { showingAdd = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List(model.items) { item in
                    DownloadRowView(item: item,
                                    speed: model.speed(for: item),
                                    onToggle: { toggle(item) },
                                    onRemove: { model.remove(item) })
                }
                .listStyle(.inset)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Tambah Unduhan", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddDownloadView { urlString in
                model.add(urlString: urlString)
            }
        }
    }

    private func toggle(_ item: DownloadItem) {
        switch item.state {
        case .downloading: model.pause(item)
        case .paused, .queued, .failed: model.start(item)
        case .completed: break
        }
    }
}
