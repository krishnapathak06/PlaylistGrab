import Foundation
import AppKit

@MainActor
final class DownloadJob: ObservableObject, Identifiable {
    enum State {
        case queued, running, processing, done, failed, cancelled
    }

    let id = UUID()
    let entry: VideoEntry
    let mode: MediaMode
    let directory: URL
    let filePrefix: String
    let subtitleLanguage: String?
    let formatPreference: VideoFormatPreference

    @Published var state: State = .queued
    @Published var progress: Double = 0
    @Published var statusText: String = "Waiting…"
    @Published var speedText: String = ""
    @Published var errorText: String?

    private(set) var outputPath: String?
    private var stagesDone = 0
    private var cancelRequested = false
    private var lastError: String?
    private var runner = DownloadRunner()

    init(entry: VideoEntry,
         mode: MediaMode,
         directory: URL,
         filePrefix: String,
         subtitleLanguage: String?,
         formatPreference: VideoFormatPreference) {
        self.entry = entry
        self.mode = mode
        self.directory = directory
        self.filePrefix = filePrefix
        self.subtitleLanguage = subtitleLanguage
        self.formatPreference = formatPreference
    }

    var isActive: Bool { state == .running || state == .processing }
    var isFinished: Bool { state == .done || state == .failed || state == .cancelled }

    // MARK: - Control

    func prepareForRun() {
        runner.reset()
        state = .running
        progress = 0
        stagesDone = 0
        cancelRequested = false
        lastError = nil
        errorText = nil
        speedText = ""
        statusText = "Starting…"
    }

    func requestCancel() {
        switch state {
        case .queued:
            state = .cancelled
            statusText = "Cancelled"
        case .running, .processing:
            cancelRequested = true
            runner.cancel()
        default:
            break
        }
    }

    func resetForRetry() {
        runner.reset()
        cancelRequested = false
        lastError = nil
        state = .queued
        progress = 0
        stagesDone = 0
        statusText = "Waiting…"
        speedText = ""
        errorText = nil
    }

    func revealInFinder() {
        if let path = outputPath, FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        } else {
            NSWorkspace.shared.open(directory)
        }
    }

    // MARK: - Running

    func execute() async {
        ToolPaths.installBundledYTDLPIfNeeded()
        guard let exe = ToolPaths.ytdlp else {
            fail("The download engine (yt-dlp) wasn’t found.")
            return
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let code = await runner.run(executable: exe, arguments: buildArguments()) { [weak self] line in
            Task { @MainActor in
                self?.handle(line)
            }
        }

        if cancelRequested {
            state = .cancelled
            statusText = "Cancelled"
            speedText = ""
            return
        }
        if code == 0 {
            state = .done
            progress = 1
            statusText = "Done"
            speedText = ""
        } else {
            fail(lastError ?? "The download failed (yt-dlp exited with code \(code)).")
        }
    }

    private func fail(_ message: String) {
        state = .failed
        statusText = "Failed"
        speedText = ""
        if CookieManager.isBotOrAuthError(message) {
            errorText = "YouTube bot check: 'Sign in to confirm you’re not a bot.' Open Settings → Authentication to pass browser cookies."
        } else {
            errorText = message
        }
    }

    private func buildArguments() -> [String] {
        var args: [String] = [
            "--ignore-config",
            "--no-playlist",
            "--newline",
            "--no-colors",
            "--no-mtime",
            "--no-overwrites",
            "--retries", "10",
            "--fragment-retries", "10",
            "--concurrent-fragments", "4",
            "--trim-filenames", "180",
            "--progress-template",
            "download:PGP|%(progress.status)s|%(progress.downloaded_bytes)s|%(progress.total_bytes)s|%(progress.total_bytes_estimate)s|%(progress.speed)s|%(progress.eta)s",
        ]

        if let deno = ToolPaths.deno {
            args += ["--js-runtimes", "deno:\(deno.path)"]
        }
        if let ffmpeg = ToolPaths.ffmpegDir {
            args += ["--ffmpeg-location", ffmpeg.path]
        }
        args += CookieManager.buildArguments()

        switch mode {
        case .audio:
            args += ["-f", "bestaudio/best", "-x", "--audio-format", "mp3", "--audio-quality", "0"]
        case .video:
            switch formatPreference {
            case .compatibleMP4:
                args += [
                    "-f", "bv*[vcodec^=avc1][height<=1080]+ba[ext=m4a]/b[ext=mp4]/bv*+ba/b",
                    "--merge-output-format", "mp4",
                ]
            case .highestQuality:
                args += ["-f", "bv*+ba/b", "--merge-output-format", "mkv"]
            }
            if let lang = subtitleLanguage {
                args += ["--write-subs", "--write-auto-subs", "--sub-langs", lang, "--convert-subs", "srt"]
            }
        }

        // In an output template, a literal % must be written as %%.
        let safeDir = directory.path.replacingOccurrences(of: "%", with: "%%")
        let safePrefix = filePrefix.replacingOccurrences(of: "%", with: "%%")
        args += ["-o", "\(safeDir)/\(safePrefix)%(title)s.%(ext)s"]

        args.append(entry.url)
        return args
    }

    // MARK: - Output parsing

    private func handle(_ line: String) {
        if line.hasPrefix("PGP|") {
            handleProgress(line)
            return
        }

        if line.hasPrefix("ERROR:") {
            var message = String(line.dropFirst("ERROR:".count)).trimmed
            if message.count > 300 { message = String(message.prefix(300)) + "…" }
            lastError = message
        }

        if let path = Self.extractPath(from: line) {
            outputPath = path
        }

        guard isActive else { return }

        if line.hasPrefix("[Merger]") {
            markProcessing("Merging video and audio…")
        } else if line.hasPrefix("[ExtractAudio]") {
            markProcessing("Converting to MP3…")
        } else if line.hasPrefix("[SubtitlesConvertor]") || line.hasPrefix("[FFmpegSubtitlesConvertor]") {
            markProcessing("Converting subtitles…")
        } else if line.hasPrefix("[VideoConvertor]") {
            markProcessing("Converting video…")
        }
    }

    private func markProcessing(_ text: String) {
        state = .processing
        statusText = text
        speedText = ""
        progress = max(progress, 0.97)
    }

    private func handleProgress(_ line: String) {
        guard isActive else { return }
        let parts = line.components(separatedBy: "|")
        guard parts.count >= 7 else { return }

        let status = parts[1]
        if status == "finished" {
            stagesDone += 1
            return
        }
        guard status == "downloading" else { return }

        // Video downloads fetch video and audio separately, so they count as two stages.
        let expectedStages = (mode == .video) ? 2.0 : 1.0
        var fraction = 0.0
        if let downloaded = Double(parts[2]),
           let total = Double(parts[3]) ?? Double(parts[4]),
           total > 0 {
            fraction = min(1, downloaded / total)
        }
        let overall = min(0.96, (Double(stagesDone) + fraction) / expectedStages)
        progress = max(progress, overall)

        state = .running
        statusText = "Downloading"
        if let speed = Double(parts[5]) {
            var text = Fmt.speed(speed)
            if let eta = Double(parts[6]) {
                text += " · " + Fmt.eta(Int(eta))
            }
            speedText = text
        } else {
            speedText = ""
        }
    }

    private static func extractPath(from line: String) -> String? {
        if line.hasPrefix("[Merger] Merging formats into \""),
           let first = line.firstIndex(of: "\""),
           let last = line.lastIndex(of: "\""),
           first < last {
            return String(line[line.index(after: first)..<last])
        }
        for prefix in ["[ExtractAudio] Destination: ", "[download] Destination: "] {
            if line.hasPrefix(prefix) {
                let path = String(line.dropFirst(prefix.count))
                if path.hasSuffix(".vtt") || path.hasSuffix(".srt") { return nil }
                return path
            }
        }
        let suffix = " has already been downloaded"
        if line.hasPrefix("[download] "), line.hasSuffix(suffix) {
            return String(line.dropFirst("[download] ".count).dropLast(suffix.count))
        }
        return nil
    }
}
