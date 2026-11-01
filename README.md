# DM+

Download manager macOS original bergaya IDM — lahir dari hasil reverse
engineering installer IDM 6.43 build 16 (peta fiturnya), bukan port kode
Tonec: semua kode di sini ditulis dari nol.

## Fitur (v0.1 scaffold)

- **Segmented download** — file dipecah ke s.d. 8 koneksi paralel (HTTP
  Range) lewat `SegmentPlanner` + `DownloadEngine`.
- **Resume beneran** — pause = cancel task; file `.segN.part` tetap di
  disk dan unduhan berikutnya melanjutkan tiap segmen dari byte terakhir.
  Daftar unduhan persisten (JSON) — yang sedang berjalan saat app ditutup
  kembali sebagai *paused*.
- **Probe server** — HEAD (fallback GET 1 byte) untuk ukuran total +
  dukungan Range; server tanpa Range jatuh ke unduhan satu aliran
  (tetap bisa resume bila Range didukung sebagian).
- **Kategori file otomatis** dari ekstensi (video/audio/dokumen/arsip/
  aplikasi/gambar) — versi DMPlus dari tabel IDMFType-nya IDM.
- **Jujur soal data** — ukuran total yang tidak dilaporkan server tampil
  sebagai progres tak tentu, tidak pernah dikarang.

Hasil unduhan masuk ke `~/Downloads/DMPlus/`.

## Struktur

- `Sources/DMPlusKit` — logika murni + engine (Foundation saja, teruji unit).
- `Sources/DMPlusApp` — SwiftUI: daftar unduhan, tambah URL, pause/resume.
- `Tests/DMPlusKitTests` — 17 unit test (planner, kategori, format, meter,
  store, item).

## Build & tes

```sh
swift test                 # unit test DMPlusKit
swift run DMPlus          # jalankan app (debug)
./scripts/build-app.sh     # dist/DMPlus.app standalone
open dist/DMPlus.app
```

Butuh macOS 14+ dan Xcode/Swift 5.9+.

## Roadmap

- Fase 2: batas kecepatan global, antrian terjadwal, drag & drop URL.
- Fase 3: integrasi browser (ekstensi + native messaging, pola IDMMsgHost).
