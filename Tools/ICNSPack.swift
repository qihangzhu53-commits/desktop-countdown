import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: ICNSPack <iconset-directory> <output.icns>\n", stderr)
    exit(2)
}

let iconsetURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

let entries: [(type: String, filename: String)] = [
    ("icp4", "icon_16x16.png"),
    ("ic11", "icon_16x16@2x.png"),
    ("icp5", "icon_32x32.png"),
    ("ic12", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic13", "icon_128x128@2x.png"),
    ("ic08", "icon_256x256.png"),
    ("ic14", "icon_256x256@2x.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

func fourBytes(_ string: String) -> Data {
    let bytes = Array(string.utf8)
    precondition(bytes.count == 4)
    return Data(bytes)
}

func bigEndianUInt32(_ value: UInt32) -> Data {
    var bigEndian = value.bigEndian
    return Data(bytes: &bigEndian, count: MemoryLayout<UInt32>.size)
}

var body = Data()
for entry in entries {
    let fileURL = iconsetURL.appendingPathComponent(entry.filename)
    let payload = try Data(contentsOf: fileURL)
    body.append(fourBytes(entry.type))
    body.append(bigEndianUInt32(UInt32(payload.count + 8)))
    body.append(payload)
}

var icns = Data()
icns.append(fourBytes("icns"))
icns.append(bigEndianUInt32(UInt32(body.count + 8)))
icns.append(body)
try icns.write(to: outputURL, options: .atomic)
