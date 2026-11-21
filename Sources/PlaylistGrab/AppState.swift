import Foundation
import AppKit

enum SidebarSection: Hashable {
    case new
    case downloads
}

@MainActor
final class AppState: ObservableObject {
    @Published var section: SidebarSection? = .new

    // New download
    @Published var urlText = ""
    @Published var mode: MediaMode = .video
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

    var selectedCount: Int { entries.filter { $0.isSelected }.count }
    var hasFinishedJobs: Bool { jobs.contains { $0.isFinished } }

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

        Task {
            do {
                let source = try await Fetcher.fetch(link)
                sourceTitle = source.title
                sourceIsPlaylist = source.isPlaylist
                sourceTotal = source.entries.count
                entries = source.entries
                hasSource = true
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

    // MARK: - Queue

    func downloadSelected() {
        let chosen = entries.filter { $0.isSelected }
        guard !chosen.isEmpty else { return }

        let defaults = UserDefaults.standard
        let folder = defaults.string(forKey: "downloadFolder") ?? AppDefaults.downloadFolder
        var directory = URL(fileURLWithPath: folder, isDirectory: true)
        if sourceIsPlaylist {
            directory.appendPathComponent(Fmt.safeName(sourceTitle, fallback: "Playlist"), isDirectory: true)
        }

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
                formatPreference: preference))
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

    func clearFinished() {
        jobs.removeAll { $0.isFinished }
        refreshCounts()
    }

    private func refreshCounts() {
        activeCount = jobs.filter { !$0.isFinished }.count
        revision &+= 1
    }
}
