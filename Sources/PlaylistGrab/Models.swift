import Foundation

/// Keys and default values for user settings.
enum AppDefaults {
    static let downloadFolder = (NSHomeDirectory() as NSString).appendingPathComponent("Downloads")

    static let registered: [String: Any] = [
        "maxParallel": 3,
        "downloadFolder": downloadFolder,
        "videoFormat": VideoFormatPreference.compatibleMP4.rawValue,
        "autoUpdateYTDLP": true,
        "subsEnabled": false,
        "subLang": "en",
    ]
}

enum MediaMode: String, CaseIterable, Identifiable {
    case video = "Video"
    case audio = "Audio (MP3)"

    var id: String { rawValue }
}

enum VideoFormatPreference: String, CaseIterable, Identifiable {
    case compatibleMP4
    case highestQuality

    var id: String { rawValue }

    var label: String {
        switch self {
        case .compatibleMP4: return "Most compatible (MP4, up to 1080p)"
        case .highestQuality: return "Highest quality (MKV, up to 4K and beyond)"
        }
    }
}

/// One video in a playlist (or a single video).
struct VideoEntry: Identifiable, Hashable {
    let index: Int          // 1-based position in the playlist
    let title: String
    let duration: Double?   // seconds
    let url: String
    var videoId: String? = nil
    var isSelected: Bool = true
    var isDownloaded: Bool = false

    var id: Int { index }
}

struct SubtitleLanguage: Identifiable, Hashable {
    let code: String
    let name: String
    var id: String { code }

    static let all: [SubtitleLanguage] = [
        ("en", "English"), ("hi", "Hindi"), ("es", "Spanish"), ("fr", "French"),
        ("de", "German"), ("pt", "Portuguese"), ("it", "Italian"), ("nl", "Dutch"),
        ("ru", "Russian"), ("ja", "Japanese"), ("ko", "Korean"),
        ("zh-Hans", "Chinese (Simplified)"), ("zh-Hant", "Chinese (Traditional)"),
        ("ar", "Arabic"), ("tr", "Turkish"), ("id", "Indonesian"),
        ("bn", "Bengali"), ("ta", "Tamil"), ("te", "Telugu"), ("mr", "Marathi"),
        ("ur", "Urdu"),
    ].map { SubtitleLanguage(code: $0.0, name: $0.1) }
}
