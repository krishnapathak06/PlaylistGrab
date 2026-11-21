import Foundation

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

enum Fmt {
    /// 3725 -> "1:02:05", 65 -> "1:05"
    static func duration(_ seconds: Double?) -> String {
        guard let s = seconds, s > 0 else { return "" }
        let total = Int(s.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let sec = total % 60
        if h > 0 { return "\(h):\(pad2(m)):\(pad2(sec))" }
        return "\(m):\(pad2(sec))"
    }

    static func pad2(_ n: Int) -> String {
        n < 10 ? "0\(n)" : "\(n)"
    }

    /// Left-pads a number with zeros to the given width: (7, 2) -> "07"
    static func zeroPad(_ n: Int, width: Int) -> String {
        let s = String(n)
        if s.count >= width { return s }
        return String(repeating: "0", count: width - s.count) + s
    }

    static func speed(_ bytesPerSecond: Double) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: Int64(bytesPerSecond)) + "/s"
    }

    static func eta(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        if m >= 60 {
            return "\(m / 60):\(pad2(m % 60)):\(pad2(s)) left"
        }
        return "\(m):\(pad2(s)) left"
    }

    /// Makes a string safe to use as a single folder or file name on macOS.
    static func safeName(_ s: String, fallback: String) -> String {
        let mapped = s.unicodeScalars.map { scalar -> Character in
            if scalar == "/" || scalar == ":" || scalar == "\\" || scalar.value < 32 {
                return "-"
            }
            return Character(scalar)
        }
        var str = String(mapped).trimmed
        while str.hasPrefix(".") { str.removeFirst() }
        if str.count > 120 {
            str = String(str.prefix(120)).trimmed
        }
        return str.isEmpty ? fallback : str
    }
}
