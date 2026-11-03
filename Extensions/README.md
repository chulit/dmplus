# Integrasi Browser DM+

Pola yang sama dengan IDM: ekstensi browser + native messaging host
(`DMPlusMsgHost`, padanan `IDMMsgHost.exe`).

## Cara kerja

1. Ekstensi Chrome (`Chrome/`) mengambil alih unduhan browser dan menu
   konteks "Download with DM+", lalu mengirim URL ke host lewat
   Native Messaging.
2. `DMPlusMsgHost` menulis URL ke `~/Library/Application Support/DMPlus/inbox.jsonl`.
3. App DM+ memeriksa inbox itu tiap 3 detik dan memulai unduhannya.

## Pasang

```sh
swift build -c release
./Extensions/install-host.sh
```

Lalu di `chrome://extensions` (mode Developer): *Load unpacked* →
pilih folder `Extensions/Chrome`, salin ID ekstensinya ke file
`~/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.chulit.dmplus.json`
(ganti `EXTENSION_ID_HERE`), dan muat ulang ekstensi.

## Troubleshooting

- **Unduhan di Chrome hilang tapi tidak masuk DM+**: hampir selalu
  karena `allowed_origins` di manifest host masih berisi
  `EXTENSION_ID_HERE` atau ID ekstensi yang salah — Chrome menolak
  koneksi native-nya. Samakan dengan ID di kartu ekstensi
  `chrome://extensions`, reload ekstensinya, mulai ulang Chrome.
- Ekstensi versi terbaru tidak membatalkan unduhan Chrome bila
  serah-terima ke host gagal — unduhan berjalan normal di browser.
