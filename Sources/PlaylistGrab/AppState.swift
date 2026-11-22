import Foundation
import AppKit

enum SidebarSection: Hashable {
    case new
    case downloads
}

@MainActor
final class AppState: ObservableObject {
    @Published var section: SidebarSection? = .new

    // Settings presentation
    @Published var showSettings = false
    @Published var settingsTab: SettingsTab = .cookies

    func openSettings(tab: SettingsTab = .general) {
        settingsTab = tab
        showSettings = true
    }

    // New download
    @Published var urlText = ""
    @Published var mode: MediaMode = .video
    @Published var videoQuality: VideoQuality = {
        let raw = UserDefaults.standard.string(forKey: "videoQuality") ?? VideoQuality.q1080p.rawValue
        return VideoQuality(rawValue: raw) ?? .q1080p
    }() {
        didSet {
            UserDefaults.standard.set(videoQuality.rawValue, forKey: "videoQuality")
        }
    }
    @Published var audioQuality: AudioQuality = {
        let raw = UserDefaults.standard.string(forKey: "audioQuality") ?? AudioQuality.best.rawValue
        return AudioQuality(rawValue: raw) ?? .best
    }() {
        didSet {
            UserDefaults.standard.set(audioQuality.rawValue, forKey: "audioQuality")
        }
    }
    @Published var entries: [VideoEntry] = []
    @Published var sourceTitle = ""
    @Published var sourceIsPlaylist = false
    @Published var hasSource = false
    @Published var isFetching = false
    @Published var fetchError: String?

    // Queue
    @Published var jobs: [DownloadJob] = []
    @Published var activeCount = 0
    /// Bumped whenever a job changes state, so views that depend on job states refresh.
    @Published var revision = 0

    private var sourceTotal = 0
    private(set) var lastClickedIndex: Int?

    var selectedCount: Int { entries.filter { $0.isSelected }.count }
    var hasFinishedJobs: Bool { jobs.contains { $0.isFinished } }
    var failedCount: Int { jobs.filter { $0.state == .failed }.count }
    var hasFailedJobs: Bool { failedCount > 0 }
    var downloadedEntriesCount: Int { entries.filter { $0.isDownloaded }.count }
    var missingEntriesCount: Int { entries.filter { !$0.isDownloaded }.count }

    // MARK: - Fetching

    func fetch() {
        let link = urlText.trimmed
        guard !link.isEmpty, !isFetching else { return }

        guard let url = URL(string: link), let scheme = url.scheme, scheme.hasPrefix("http") else {
            fetchError = "That doesn’t look like a link. Paste a full address starting with https://"
            return
        }

        isFetching = true
        fetchError = nil
        hasSource = false
        entries = []
        lastClickedIndex = nil

        Task {
            do {
                let source = try await Fetcher.fetch(link)
                sourceTitle = source.title
                sourceIsPlaylist = source.isPlaylist
                sourceTotal = source.entries.count
                entries = source.entries
                hasSource = true
                checkExistingDownloads()
            } catch {
                fetchError = error.localizedDescription
            }
            isFetching = false
        }
    }

    func setAllSelected(_ selected: Bool) {
        for i in entries.indices {
            entries[i].isSelected = selected
        }
    }

    func selectMissingOnly() {
        for i in entries.indices {
            entries[i].isSelected = !entries[i].isDownloaded
        }
    }

    func selectRangeOnly(_ indices: Set<Int>) {
        for i in entries.indices {
            entries[i].isSelected = indices.contains(entries[i].index)
        }
    }

    func addRangeToSelection(_ indices: Set<Int>) {
        for i in entries.indices {
            if indices.contains(entries[i].index) {
                entries[i].isSelected = true
            }
        }
    }

    func removeRangeFromSelection(_ indices: Set<Int>) {
        for i in entries.indices {
            if indices.contains(entries[i].index) {
                entries[i].isSelected = false
            }
        }
    }

    func invertSelection() {
        for i in entries.indices {
            entries[i].isSelected.toggle()
        }
    }

    func toggleEntrySelection(at index: Int, shiftHeld: Bool) {
        guard index >= 0 && index < entries.count else { return }
        if shiftHeld, let last = lastClickedIndex, last >= 0 && last < entries.count {
            let targetState = entries[last].isSelected
            let range = min(last, index)...max(last, index)
            for i in range {
                entries[i].isSelected = targetState
            }
        } else {
            entries[index].isSelected.toggle()
            lastClickedIndex = index
        }
    }

    /// Resolves the final destination folder, handling cases where the user directly selected the playlist folder.
    func resolvedDestination(forFolder folder: String? = nil) -> URL {
        let basePath = folder ?? (UserDefaults.standard.string(forKey: "downloadFolder") ?? AppDefaults.downloadFolder)
        let baseURL = URL(fileURLWithPath: basePath, isDirectory: true)
        guard sourceIsPlaylist, !sourceTitle.isEmpty else { return baseURL }
        let playlistFolderName = Fmt.safeName(sourceTitle, fallback: "Playlist")
        if baseURL.lastPathComponent.caseInsensitiveCompare(playlistFolderName) == .orderedSame {
            return baseURL
        }
        return baseURL.appendingPathComponent(playlistFolderName, isDirectory: true)
    }

    /// Checks the destination directory for previously downloaded videos.
    func checkExistingDownloads(in folder: String? = nil) {
        guard hasSource, !entries.isEmpty else { return }
        let dest = resolvedDestination(forFolder: folder)
        guard FileManager.default.fileExists(atPath: dest.path) else {
            for i in entries.indices {
                entries[i].isDownloaded = false
            }
            return
        }

        let files = (try? FileManager.default.contentsOfDirectory(atPath: dest.path)) ?? []
        let validExtensions: Set<String> = ["mp4", "mkv", "webm", "mp3", "m4a", "opus", "flac", "wav", "aac", "mov"]
        let mediaFiles = files.filter { file in
            guard !file.hasPrefix(".") else { return false }
            guard !file.hasSuffix(".part") && !file.hasSuffix(".ytdl") && !file.hasSuffix(".temp") else { return false }
            let ext = (file as NSString).pathExtension.lowercased()
            return validExtensions.contains(ext)
        }

        let width = max(2, String(sourceTotal).count)
        for i in entries.indices {
            let entry = entries[i]
            let exists = FileChecker.isDownloaded(entry: entry, files: mediaFiles, isPlaylist: sourceIsPlaylist, padWidth: width)
            entries[i].isDownloaded = exists
            if exists {
                entries[i].isSelected = false
            }
        }
    }

    // MARK: - Queue

    func downloadSelected() {
        let chosen = entries.filter { $0.isSelected }
        guard !chosen.isEmpty else { return }

        let defaults = UserDefaults.standard
        let folder = defaults.string(forKey: "downloadFolder") ?? AppDefaults.downloadFolder
        let directory = resolvedDestination(forFolder: folder)

        let width = max(2, String(sourceTotal).count)
        let wantsSubtitles = mode == .video && defaults.bool(forKey: "subsEnabled")
        let language = defaults.string(forKey: "subLang") ?? "en"
        let preference = VideoFormatPreference(rawValue: defaults.string(forKey: "videoFormat") ?? "") ?? .compatibleMP4

        for entry in chosen {
            let prefix = sourceIsPlaylist ? "\(Fmt.zeroPad(entry.index, width: width)) - " : ""
            jobs.append(DownloadJob(
                entry: entry,
                mode: mode,
                directory: directory,
                filePrefix: prefix,
                subtitleLanguage: wantsSubtitles ? language : nil,
                formatPreference: preference,
                videoQuality: videoQuality,
                audioQuality: audioQuality))
        }

        section = .downloads
        pump()
    }

    /// Starts queued jobs until the parallel limit is reached.
    func pump() {
        let limit = max(1, UserDefaults.standard.integer(forKey: "maxParallel"))
        var running = jobs.filter { $0.isActive }.count
        for job in jobs where job.state == .queued {
            if running >= limit { break }
            start(job)
            running += 1
        }
        refreshCounts()
    }

    private func start(_ job: DownloadJob) {
        job.prepareForRun()
        Task { [weak self] in
            await job.execute()
            self?.pump()
        }
    }

    func cancel(_ job: DownloadJob) {
        job.requestCancel()
        refreshCounts()
    }

    func retry(_ job: DownloadJob) {
        job.resetForRetry()
        pump()
    }

    func retryAllFailed() {
        for job in jobs where job.state == .failed {
            job.resetForRetry()
        }
        pump()
    }

    func clearFinished() {
        jobs.removeAll { $0.isFinished }
        refreshCounts()
    }

    private func refreshCounts() {
        activeCount = jobs.filter { !$0.isFinished }.count
        revision &+= 1
    }
}
