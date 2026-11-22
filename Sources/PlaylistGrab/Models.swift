import Foundation

/// Keys and default values for user settings.
enum AppDefaults {
    static let downloadFolder = (NSHomeDirectory() as NSString).appendingPathComponent("Downloads")

    static let registered: [String: Any] = [
        "maxParallel": 3,
        "downloadFolder": downloadFolder,
        "videoFormat": VideoFormatPreference.compatibleMP4.rawValue,
        "videoQuality": VideoQuality.q1080p.rawValue,
        "audioQuality": AudioQuality.best.rawValue,
        "autoUpdateYTDLP": true,
        "subsEnabled": false,
        "subLang": "en",
        "cookieSource": CookieSourceType.browser.rawValue,
        "cookieBrowser": SupportedBrowser.chrome.rawValue,
        "cookieFilePath": "",
        "cookieManualText": "",
    ]
}

enum MediaMode: String, CaseIterable, Identifiable {
    case video = "Video"
    case audio = "Audio (MP3)"

    var id: String { rawValue }
}

enum VideoQuality: String, CaseIterable, Identifiable {
    case best = "best"
    case q2160p = "2160p"
    case q1440p = "1440p"
    case q1080p = "1080p"
    case q720p = "720p"
    case q480p = "480p"
    case q360p = "360p"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .best: return "Best Available"
        case .q2160p: return "4K (2160p)"
        case .q1440p: return "2K (1440p)"
        case .q1080p: return "1080p (Full HD)"
        case .q720p: return "720p (HD)"
        case .q480p: return "480p"
        case .q360p: return "360p"
        }
    }

    var shortLabel: String {
        switch self {
        case .best: return "Best"
        case .q2160p: return "4K"
        case .q1440p: return "2K"
        case .q1080p: return "1080p"
        case .q720p: return "720p"
        case .q480p: return "480p"
        case .q360p: return "360p"
        }
    }

    var maxHeight: Int? {
        switch self {
        case .best: return nil
        case .q2160p: return 2160
        case .q1440p: return 1440
        case .q1080p: return 1080
        case .q720p: return 720
        case .q480p: return 480
        case .q360p: return 360
        }
    }
}

enum AudioQuality: String, CaseIterable, Identifiable {
    case best = "0"
    case high = "192"
    case medium = "128"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .best: return "Best (320 kbps)"
        case .high: return "High (192 kbps)"
        case .medium: return "Standard (128 kbps)"
        }
    }

    var shortLabel: String {
        switch self {
        case .best: return "320k"
        case .high: return "192k"
        case .medium: return "128k"
        }
    }
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
