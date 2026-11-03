import SwiftUI
import DMPlusKit

/// Site Grabber: fetch a page, list every downloadable link in it,
/// pick, and send them all to the queue — IDM's Grabber, simplified.
struct GrabberView: View {
    @Bindable var model: DownloadListModel
    @Environment(\.dismiss) private var dismiss
    @State private var pageURLString = ""
    @State private var links: [LinkExtractor.FoundLink] = []
    @State private var selected: Set<String> = []
    @State private var categoryFilter: FileCategory?
    @State private var status = ""
    @State private var isFetching = false

    private var visibleLinks: [LinkExtractor.FoundLink] {
        guard let categoryFilter else { return links }
        return links.filter { $0.category == categoryFilter }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Site Grabber").font(.title2).bold()
            HStack {
                TextField("https://contoh.com/halaman/", text: $pageURLString)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { fetch() }
                Button("Ambil Tautan") { fetch() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isFetching || URL(string: pageURLString) == nil)
            }
            if !status.isEmpty {
                Text(status).font(.caption).foregroundStyle(.secondary)
            }
            Picker("Filter", selection: $categoryFilter) {
                Text("Semua").tag(FileCategory?.none)
                ForEach(FileCategory.allCases, id: \.self) { category in
                    Text(category.displayName).tag(FileCategory?.some(category))
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            List(visibleLinks, id: \.url) { link in
                Toggle(isOn: selectionBinding(for: link)) {
                    HStack {
                        Image(systemName: link.category.symbolName).foregroundStyle(.secondary)
                        VStack(alignment: .leading) {
                            Text(link.url.lastPathComponent).lineLimit(1)
                            Text(link.url.absoluteString)
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                .toggleStyle(.checkbox)
            }
            .frame(height: 260)

            HStack {
                Button("Pilih Semua") {
                    selected = Set(visibleLinks.map { $0.url.absoluteString })
                }
                Button("Kosongkan") { selected.removeAll() }
                Spacer()
                Button("Batal") { dismiss() }
                Button("Tambah \(selected.count) ke Antrian") { submit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(selected.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 560)
    }

    private func selectionBinding(for link: LinkExtractor.FoundLink) -> Binding<Bool> {
        Binding(
            get: { selected.contains(link.url.absoluteString) },
            set: { on in
                if on { selected.insert(link.url.absoluteString) }
                else { selected.remove(link.url.absoluteString) }
            })
    }

    private func fetch() {
        guard let url = URL(string: pageURLString.trimmingCharacters(in: .whitespaces)),
              url.scheme == "http" || url.scheme == "https" else { return }
        isFetching = true
        status = "Mengambil halaman…"
        Task {
            defer { isFetching = false }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let html = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .isoLatin1) ?? ""
                links = LinkExtractor.extract(from: html, baseURL: url)
                selected = Set(links.map { $0.url.absoluteString })
                status = links.isEmpty
                    ? "Tidak ada tautan unduhan ditemukan di halaman ini."
                    : "Ditemukan \(links.count) tautan."
            } catch {
                status = "Gagal mengambil halaman: \(error.localizedDescription)"
            }
        }
    }

    private func submit() {
        for link in links where selected.contains(link.url.absoluteString) {
            model.add(url: link.url, startImmediately: false)
        }
        dismiss()
    }
}
