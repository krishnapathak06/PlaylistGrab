import Foundation

struct FetchedSource {
    let title: String
    let isPlaylist: Bool
    let entries: [VideoEntry]
}

enum FetchError: LocalizedError {
    case toolMissing
    case failed(String)
    case unreadable

    var errorDescription: String? {
        switch self {
        case .toolMissing:
            return "The download engine (yt-dlp) wasn’t found. Reinstall the app, or run it from the official release."
        case .failed(let message):
            return message
        case .unreadable:
            return "Couldn’t understand the response for this link."
        }
    }
}

enum Fetcher {
    /// Asks yt-dlp what is behind a link: one video, or a playlist and its videos.
    static func fetch(_ urlString: String) async throws -> FetchedSource {
        ToolPaths.installBundledYTDLPIfNeeded()
        guard let exe = ToolPaths.ytdlp else { throw FetchError.toolMissing }

        var args = ["--ignore-config", "--flat-playlist", "-J", "--no-warnings"]
        if let deno = ToolPaths.deno {
            args += ["--js-runtimes", "deno:\(deno.path)"]
        }
        args += CookieManager.buildArguments()
        args.append(urlString)

        let result = await runCapture(executable: exe, arguments: args)
        guard result.status == 0 else {
            throw FetchError.failed(friendlyError(result.stderr))
        }
        guard let data = result.stdout.data(using: .utf8),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw FetchError.unreadable
        }

        if (json["_type"] as? String) == "playlist", let rawEntries = json["entries"] as? [Any] {
            var list: [VideoEntry] = []
            for (offset, raw) in rawEntries.enumerated() {
                guard let entry = raw as? [String: Any] else { continue }
                let id = entry["id"] as? String ?? ""
                let title = (entry["title"] as? String) ?? "Untitled video"
                let duration = (entry["duration"] as? NSNumber)?.doubleValue
                list.append(VideoEntry(
                    index: offset + 1,
                    title: title,
                    duration: duration,
                    url: videoURL(for: entry, id: id),
                    videoId: id.isEmpty ? nil : id))
            }
            guard !list.isEmpty else {
                throw FetchError.failed("This playlist doesn’t contain any videos that can be listed.")
            }
            let title = (json["title"] as? String) ?? "Playlist"
            return FetchedSource(title: title, isPlaylist: true, entries: list)
        }

        // A single video.
        let title = (json["title"] as? String) ?? "Video"
        let duration = (json["duration"] as? NSNumber)?.doubleValue
        let url = (json["webpage_url"] as? String) ?? urlString
        let id = json["id"] as? String
        let entry = VideoEntry(
            index: 1,
            title: title,
            duration: duration,
            url: url,
            videoId: (id?.isEmpty == false) ? id : nil)
        return FetchedSource(title: title, isPlaylist: false, entries: [entry])
    }

    private static func videoURL(for entry: [String: Any], id: String) -> String {
        if let url = entry["url"] as? String, url.hasPrefix("http") { return url }
        if let url = entry["webpage_url"] as? String, url.hasPrefix("http") { return url }
        return "https://www.youtube.com/watch?v=\(id)"
    }

    /// Turns yt-dlp's raw error output into one readable sentence.
    static func friendlyError(_ stderr: String) -> String {
        if CookieManager.isBotOrAuthError(stderr) {
            return "YouTube bot verification triggered: 'Sign in to confirm you’re not a bot.' Please enable browser cookies or import a cookies.txt file in Settings → Authentication."
        }
        let lines = stderr
            .components(separatedBy: .newlines)
            .map { $0.trimmed }
            .filter { !$0.isEmpty }
        var message = lines.last(where: { $0.hasPrefix("ERROR:") }) ?? lines.last ?? "Something went wrong reading that link."
        if message.hasPrefix("ERROR:") {
            message = String(message.dropFirst("ERROR:".count)).trimmed
        }
        if message.count > 300 {
            message = String(message.prefix(300)) + "…"
        }
        return message
    }
}
