import Foundation
import Darwin

/// Where the helper programs (yt-dlp, Deno, ffmpeg, ffprobe) live.
///
/// The app bundle ships all four in Contents/Resources/bin. yt-dlp is copied into
/// Application Support on first launch, because it replaces itself when updating and
/// an app bundle must not modify itself. Deno and ffmpeg run straight from the bundle.
/// For development with `swift run`, Homebrew locations are used as a fallback.
enum ToolPaths {
    static var appSupportDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("PlaylistGrab", isDirectory: true)
    }

    static var installedBinDir: URL {
        appSupportDir.appendingPathComponent("bin", isDirectory: true)
    }

    static var bundledBinDir: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("bin", isDirectory: true)
    }

    private static let systemDirs = ["/opt/homebrew/bin", "/usr/local/bin"]

    private static func isExecutable(_ url: URL) -> Bool {
        FileManager.default.isExecutableFile(atPath: url.path)
    }

    static func find(_ name: String) -> URL? {
        var dirs: [URL] = []
        if name == "yt-dlp" { dirs.append(installedBinDir) }
        if let bundled = bundledBinDir { dirs.append(bundled) }
        dirs += systemDirs.map { URL(fileURLWithPath: $0, isDirectory: true) }
        for dir in dirs {
            let candidate = dir.appendingPathComponent(name)
            if isExecutable(candidate) { return candidate }
        }
        return nil
    }

    static var ytdlp: URL? { find("yt-dlp") }
    static var deno: URL? { find("deno") }

    /// A directory that contains both ffmpeg and ffprobe.
    static var ffmpegDir: URL? {
        var dirs: [URL] = []
        if let bundled = bundledBinDir { dirs.append(bundled) }
        dirs += systemDirs.map { URL(fileURLWithPath: $0, isDirectory: true) }
        for dir in dirs {
            if isExecutable(dir.appendingPathComponent("ffmpeg")),
               isExecutable(dir.appendingPathComponent("ffprobe")) {
                return dir
            }
        }
        return nil
    }

    /// Copies the bundled yt-dlp into Application Support if it isn't there yet.
    static func installBundledYTDLPIfNeeded() {
        let fm = FileManager.default
        let dest = installedBinDir.appendingPathComponent("yt-dlp")
        guard !isExecutable(dest),
              let source = bundledBinDir?.appendingPathComponent("yt-dlp"),
              isExecutable(source) else { return }
        do {
            try fm.createDirectory(at: installedBinDir, withIntermediateDirectories: true)
            let temp = installedBinDir.appendingPathComponent("yt-dlp.copying")
            try? fm.removeItem(at: temp)
            try fm.copyItem(at: source, to: temp)
            _ = removexattr(temp.path, "com.apple.quarantine", 0)
            _ = chmod(temp.path, 0o755)
            try? fm.removeItem(at: dest)
            try fm.moveItem(at: temp, to: dest)
        } catch {
            // If this fails, find("yt-dlp") falls back to the bundled copy.
        }
    }

    /// Deletes the updated copy so the bundled version is used (and re-copied) again.
    static func resetInstalledYTDLP() {
        try? FileManager.default.removeItem(at: installedBinDir.appendingPathComponent("yt-dlp"))
        installBundledYTDLPIfNeeded()
    }

    static func processEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        var parts: [String] = []
        if let deno = deno { parts.append(deno.deletingLastPathComponent().path) }
        if let ff = ffmpegDir { parts.append(ff.path) }
        parts += ["/usr/bin", "/bin", "/usr/sbin", "/sbin", "/opt/homebrew/bin", "/usr/local/bin"]
        env["PATH"] = parts.joined(separator: ":")
        env["LC_ALL"] = "en_US.UTF-8"
        env["PYTHONIOENCODING"] = "utf-8"
        return env
    }
}

// MARK: - Running processes

struct CaptureResult {
    let status: Int32
    let stdout: String
    let stderr: String
}

/// Thread-safe byte buffer used to collect process output from background threads.
final class DataBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func set(_ data: Data) {
        lock.lock()
        storage = data
        lock.unlock()
    }

    func get() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

/// Runs a program to completion and returns everything it printed.
func runCapture(executable: URL, arguments: [String]) async -> CaptureResult {
    await withCheckedContinuation { (continuation: CheckedContinuation<CaptureResult, Never>) in
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments
            process.environment = ToolPaths.processEnvironment()
            process.currentDirectoryURL = FileManager.default.temporaryDirectory
            process.standardInput = FileHandle.nullDevice

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            do {
                try process.run()
            } catch {
                continuation.resume(returning: CaptureResult(
                    status: -1, stdout: "", stderr: "Could not start \(executable.lastPathComponent): \(error.localizedDescription)"))
                return
            }

            let outBox = DataBox()
            let errBox = DataBox()
            let group = DispatchGroup()

            group.enter()
            DispatchQueue.global().async {
                outBox.set(outPipe.fileHandleForReading.readDataToEndOfFile())
                group.leave()
            }
            group.enter()
            DispatchQueue.global().async {
                errBox.set(errPipe.fileHandleForReading.readDataToEndOfFile())
                group.leave()
            }

            process.waitUntilExit()
            group.wait()

            continuation.resume(returning: CaptureResult(
                status: process.terminationStatus,
                stdout: String(decoding: outBox.get(), as: UTF8.self),
                stderr: String(decoding: errBox.get(), as: UTF8.self)))
        }
    }
}

/// Keeps track of live download processes so they can all be stopped when the app quits.
final class RunnerRegistry: @unchecked Sendable {
    static let shared = RunnerRegistry()

    private let lock = NSLock()
    private var runners: [ObjectIdentifier: DownloadRunner] = [:]

    func add(_ runner: DownloadRunner) {
        lock.lock()
        runners[ObjectIdentifier(runner)] = runner
        lock.unlock()
    }

    func remove(_ runner: DownloadRunner) {
        lock.lock()
        runners.removeValue(forKey: ObjectIdentifier(runner))
        lock.unlock()
    }

    func cancelAll() {
        lock.lock()
        let all = Array(runners.values)
        lock.unlock()
        for runner in all { runner.cancel() }
    }
}

/// Runs one long-lived process (a download) and streams its output line by line.
final class DownloadRunner: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    func cancel() {
        lock.lock()
        cancelled = true
        let running = process
        lock.unlock()
        running?.terminate()
    }

    func reset() {
        lock.lock()
        cancelled = false
        process = nil
        lock.unlock()
    }

    /// Returns the exit status. `onLine` is called from a background thread for each output line.
    func run(executable: URL,
             arguments: [String],
             onLine: @escaping @Sendable (String) -> Void) async -> Int32 {
        await withCheckedContinuation { (continuation: CheckedContinuation<Int32, Never>) in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = executable
                process.arguments = arguments
                process.environment = ToolPaths.processEnvironment()
                process.currentDirectoryURL = FileManager.default.temporaryDirectory
                process.standardInput = FileHandle.nullDevice

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                self.lock.lock()
                if self.cancelled {
                    self.lock.unlock()
                    continuation.resume(returning: 15)
                    return
                }
                do {
                    try process.run()
                } catch {
                    self.lock.unlock()
                    onLine("ERROR: Could not start \(executable.lastPathComponent): \(error.localizedDescription)")
                    continuation.resume(returning: -1)
                    return
                }
                self.process = process
                self.lock.unlock()
                RunnerRegistry.shared.add(self)

                let handle = pipe.fileHandleForReading
                var buffer = Data()
                while true {
                    let chunk = handle.availableData
                    if chunk.isEmpty { break }
                    buffer.append(chunk)
                    // Split on \n or \r so progress lines are delivered as they arrive.
                    while let breakIndex = buffer.firstIndex(where: { $0 == 10 || $0 == 13 }) {
                        let lineData = buffer.subdata(in: buffer.startIndex..<breakIndex)
                        buffer.removeSubrange(buffer.startIndex...breakIndex)
                        if !lineData.isEmpty {
                            onLine(String(decoding: lineData, as: UTF8.self))
                        }
                    }
                }
                if !buffer.isEmpty {
                    onLine(String(decoding: buffer, as: UTF8.self))
                }

                process.waitUntilExit()
                RunnerRegistry.shared.remove(self)
                continuation.resume(returning: process.terminationStatus)
            }
        }
    }
}

// MARK: - Tool status and updates

@MainActor
final class ToolManager: ObservableObject {
    static let shared = ToolManager()

    @Published var ytdlpVersion = "checking…"
    @Published var updateStatus = ""
    @Published var isUpdating = false

    private var prepared = false

    var hasDeno: Bool { ToolPaths.deno != nil }
    var hasFFmpeg: Bool { ToolPaths.ffmpegDir != nil }

    func prepareOnLaunch() async {
        guard !prepared else { return }
        prepared = true

        await Task.detached(priority: .userInitiated) {
            ToolPaths.installBundledYTDLPIfNeeded()
        }.value

        await refreshVersion()

        if UserDefaults.standard.bool(forKey: "autoUpdateYTDLP") {
            await updateYTDLP()
        }
    }

    func refreshVersion() async {
        guard let exe = ToolPaths.ytdlp else {
            ytdlpVersion = "not found"
            return
        }
        let result = await runCapture(executable: exe, arguments: ["--ignore-config", "--version"])
        ytdlpVersion = result.status == 0 ? result.stdout.trimmed : "error"
    }

    func updateYTDLP() async {
        guard !isUpdating, let exe = ToolPaths.ytdlp else { return }
        isUpdating = true
        updateStatus = "Checking for updates…"

        let result = await runCapture(executable: exe, arguments: ["--ignore-config", "-U"])
        let lines = (result.stdout + "\n" + result.stderr)
            .components(separatedBy: .newlines)
            .map { $0.trimmed }
            .filter { !$0.isEmpty }
        let lastLine = lines.last ?? ""

        if result.status == 0 {
            updateStatus = lastLine.isEmpty ? "Up to date." : lastLine
        } else {
            updateStatus = "Couldn’t update: \(lastLine)"
        }

        await refreshVersion()
        isUpdating = false
    }

    func resetYTDLP() async {
        await Task.detached(priority: .userInitiated) {
            ToolPaths.resetInstalledYTDLP()
        }.value
        updateStatus = "Reset to the version bundled with the app."
        await refreshVersion()
    }
}

// MARK: - Existing file detection

enum FileChecker {
    /// Checks whether a video entry already exists as a completed media file in the list of files.
    static func isDownloaded(entry: VideoEntry, files: [String], isPlaylist: Bool, padWidth: Int) -> Bool {
        let prefixPad = "\(Fmt.zeroPad(entry.index, width: padWidth)) - "
        let prefixSimple = "\(entry.index) - "
        let cleanTitle = normalize(entry.title)

        for file in files {
            let baseName = (file as NSString).deletingPathExtension
            if isPlaylist {
                if baseName.hasPrefix(prefixPad) || baseName.hasPrefix(prefixSimple) {
                    return true
                }
            }
            let cleanFile = normalize(baseName)
            if !cleanTitle.isEmpty && (cleanFile.contains(cleanTitle) || cleanTitle.contains(cleanFile)) {
                return true
            }
            if let id = entry.videoId, !id.isEmpty, baseName.contains(id) {
                return true
            }
        }
        return false
    }

    private static func normalize(_ s: String) -> String {
        s.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }
}
