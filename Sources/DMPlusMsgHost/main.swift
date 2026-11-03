import Foundation

// DMPlusMsgHost — Chrome Native Messaging host, the counterpart of IDM's
// IDMMsgHost.exe. Chrome starts this process and speaks length-prefixed
// JSON over stdio. Every {"url": "..."} message is appended as one line
// to Application Support/DMPlus/inbox.jsonl; the DM+ app polls that file
// (see DownloadListModel.inboxTick) and starts the download.

let inboxURL = FileManager.default.urls(
    for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("DMPlus/inbox.jsonl")
try? FileManager.default.createDirectory(
    at: inboxURL.deletingLastPathComponent(), withIntermediateDirectories: true)

let stdin = FileHandle.standardInput
let stdout = FileHandle.standardOutput

func readExactly(_ count: Int) -> Data? {
    var data = Data()
    while data.count < count {
        let chunk = stdin.readData(ofLength: count - data.count)
        if chunk.isEmpty { return nil }
        data.append(chunk)
    }
    return data
}

func sendMessage(_ object: [String: Any]) {
    guard let payload = try? JSONSerialization.data(withJSONObject: object) else { return }
    var length = UInt32(payload.count).littleEndian
    stdout.write(Data(bytes: &length, count: 4))
    stdout.write(payload)
}

while let header = readExactly(4) {
    let length = header.withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
    guard length > 0, length < 1_000_000, let body = readExactly(Int(length)),
          let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
          let url = object["url"] as? String
    else { break }
    let line = "{\"url\": \(jsonString(url))}\n"
    if let handle = try? FileHandle(forWritingTo: inboxURL) {
        _ = try? handle.seekToEnd()
        handle.write(line.data(using: .utf8)!)
        try? handle.close()
    } else {
        try? line.write(to: inboxURL, atomically: true, encoding: .utf8)
    }
    sendMessage(["received": true])
}

func jsonString(_ value: String) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: [value]),
          let text = String(data: data, encoding: .utf8) else { return "\"\"" }
    return String(text.dropFirst().dropLast()) // strip the [ ]
}
