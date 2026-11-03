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
