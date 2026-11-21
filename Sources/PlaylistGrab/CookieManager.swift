import Foundation
import AppKit
import UniformTypeIdentifiers

enum CookieSourceType: String, CaseIterable, Identifiable {
    case none = "None"
    case browser = "Browser"
    case file = "File"
    case manual = "Text"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "Disabled (Anonymous)"
        case .browser: return "Use Browser Cookies (Recommended)"
        case .file: return "Import cookies.txt File"
        case .manual: return "Paste Raw Cookies"
        }
    }

    var iconName: String {
        switch self {
        case .none: return "slash.circle"
        case .browser: return "globe"
        case .file: return "doc.text"
        case .manual: return "text.badge.plus"
        }
    }
}

enum SupportedBrowser: String, CaseIterable, Identifiable {
    case chrome = "chrome"
    case safari = "safari"
    case firefox = "firefox"
    case brave = "brave"
    case edge = "edge"
    case arc = "arc"
    case opera = "opera"
    case vivaldi = "vivaldi"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chrome: return "Google Chrome"
        case .safari: return "Safari"
        case .firefox: return "Firefox"
        case .brave: return "Brave"
        case .edge: return "Microsoft Edge"
        case .arc: return "Arc"
        case .opera: return "Opera"
        case .vivaldi: return "Vivaldi"
        }
    }
}

enum CookieManager {
    static var savedManualCookieURL: URL {
        ToolPaths.appSupportDir.appendingPathComponent("cookies.txt")
    }

    /// Builds yt-dlp arguments for cookies based on user preferences.
    static func buildArguments() -> [String] {
        let defaults = UserDefaults.standard
        let sourceRaw = defaults.string(forKey: "cookieSource") ?? CookieSourceType.browser.rawValue
        guard let source = CookieSourceType(rawValue: sourceRaw) else { return [] }

        switch source {
        case .none:
            return []

        case .browser:
            let browser = defaults.string(forKey: "cookieBrowser") ?? SupportedBrowser.chrome.rawValue
            return ["--cookies-from-browser", browser]

        case .file:
            let path = defaults.string(forKey: "cookieFilePath") ?? ""
            if !path.isEmpty && FileManager.default.fileExists(atPath: path) {
                return ["--cookies", path]
            }
            return []

        case .manual:
            let text = defaults.string(forKey: "cookieManualText") ?? ""
            guard !text.trimmed.isEmpty else { return [] }
            let fileURL = savedManualCookieURL
            try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? text.write(to: fileURL, atomically: true, encoding: .utf8)
            return ["--cookies", fileURL.path]
        }
    }

    static var currentStatusSummary: String {
        let defaults = UserDefaults.standard
        let sourceRaw = defaults.string(forKey: "cookieSource") ?? CookieSourceType.browser.rawValue
        guard let source = CookieSourceType(rawValue: sourceRaw) else { return "Disabled" }

        switch source {
        case .none:
            return "Cookies Off"
        case .browser:
            let browser = defaults.string(forKey: "cookieBrowser") ?? SupportedBrowser.chrome.rawValue
            let name = SupportedBrowser(rawValue: browser)?.displayName ?? browser
            return "\(name) Cookies"
        case .file:
            let path = defaults.string(forKey: "cookieFilePath") ?? ""
            if !path.isEmpty && FileManager.default.fileExists(atPath: path) {
                return (path as NSString).lastPathComponent
            }
            return "File Not Selected"
        case .manual:
            let text = defaults.string(forKey: "cookieManualText") ?? ""
            return text.trimmed.isEmpty ? "No Cookies Pasted" : "Custom Cookies"
        }
    }

    static var isConfiguredAndActive: Bool {
        let defaults = UserDefaults.standard
        let sourceRaw = defaults.string(forKey: "cookieSource") ?? CookieSourceType.browser.rawValue
        guard let source = CookieSourceType(rawValue: sourceRaw) else { return false }

        switch source {
        case .none:
            return false
        case .browser:
            return true
        case .file:
            let path = defaults.string(forKey: "cookieFilePath") ?? ""
            return !path.isEmpty && FileManager.default.fileExists(atPath: path)
        case .manual:
            let text = defaults.string(forKey: "cookieManualText") ?? ""
            return !text.trimmed.isEmpty
        }
    }

    static func isBotOrAuthError(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("sign in to confirm you’re not a bot") ||
               lower.contains("sign in to confirm you're not a bot") ||
               lower.contains("--cookies-from-browser") ||
               lower.contains("--cookies") ||
               lower.contains("bot detection") ||
               lower.contains("confirm you're not a bot") ||
               lower.contains("confirm your age")
    }

    static func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Native Dialog Pickers

enum FolderPicker {
    static func choose(startingAt path: String) -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.directoryURL = URL(fileURLWithPath: path, isDirectory: true)
        return panel.runModal() == .OK ? panel.url?.path : nil
    }
}

enum FilePicker {
    static func chooseFile(allowedExtensions: [String], startingAt path: String? = nil) -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.allowedContentTypes = allowedExtensions.compactMap { UTType(filenameExtension: $0) }
        if let path = path, !path.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: path).deletingLastPathComponent()
        }
        return panel.runModal() == .OK ? panel.url?.path : nil
    }
}
