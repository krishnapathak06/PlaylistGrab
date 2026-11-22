import SwiftUI
import AppKit

enum JobFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case active = "Active"
    case completed = "Completed"
    case failed = "Failed"

    var id: String { rawValue }
}

struct DownloadsView: View {
    @EnvironmentObject var state: AppState
    @AppStorage("downloadFolder") private var downloadFolder = AppDefaults.downloadFolder

    @State private var selectedFilter: JobFilter = .all

    private var filteredJobs: [DownloadJob] {
        switch selectedFilter {
        case .all:
            return state.jobs
        case .active:
            return state.jobs.filter { $0.isActive || $0.state == .queued }
        case .completed:
            return state.jobs.filter { $0.state == .done }
        case .failed:
            return state.jobs.filter { $0.state == .failed || $0.state == .cancelled }
        }
    }

    private var hasBotFailure: Bool {
        state.jobs.contains { job in
            job.state == .failed && CookieManager.isBotOrAuthError(job.errorText ?? "")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if state.jobs.isEmpty {
                emptyState
            } else {
                // Top Filter & Stat Bar
                topStatusBar
                Divider()
                    .opacity(0.6)

                // Bot Error Alert or General Failure Banner
                if hasBotFailure {
                    botErrorBanner
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                } else if state.hasFailedJobs {
                    failedAlertBanner
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredJobs) { job in
                            JobCard(job: job)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Downloads")
        .toolbar {
            ToolbarItemGroup {
                if state.hasFailedJobs {
                    Button {
                        state.retryAllFailed()
                    } label: {
                        Label("Retry Failed (\(state.failedCount))", systemImage: "arrow.clockwise")
                    }
                    .help("Retry all failed downloads")
                }

                Button {
                    NSWorkspace.shared.open(URL(fileURLWithPath: downloadFolder, isDirectory: true))
                } label: {
                    Label("Open Folder", systemImage: "folder")
                }
                .help("Open download destination folder")

                Button {
                    state.clearFinished()
                } label: {
                    Label("Clear Finished", systemImage: "trash")
                }
                .help("Remove finished items from list")
                .disabled(!state.hasFinishedJobs || state.revision < 0)
            }
        }
    }

    // MARK: - Top Status Bar

    private var topStatusBar: some View {
        HStack(spacing: 12) {
            Picker("Filter", selection: $selectedFilter) {
                ForEach(JobFilter.allCases) { filter in
                    Text("\(filter.rawValue) (\(count(for: filter)))").tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 380)

            Spacer()

            if state.activeCount > 0 {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text("\(state.activeCount) active")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private func count(for filter: JobFilter) -> Int {
        switch filter {
        case .all: return state.jobs.count
        case .active: return state.jobs.filter { $0.isActive || $0.state == .queued }.count
        case .completed: return state.jobs.filter { $0.state == .done }.count
        case .failed: return state.jobs.filter { $0.state == .failed || $0.state == .cancelled }.count
        }
    }

    // MARK: - Bot Error Banner

    private var botErrorBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "shield.slash.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("YouTube Bot Verification Blocked Download")
                    .font(.system(size: 13, weight: .bold))
                Text("YouTube detected automated requests. Select your browser in Settings → Authentication to pass cookies.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    state.openSettings(tab: .cookies)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "gearshape.fill")
                        Text("Open Cookie Settings")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                Button {
                    state.retryAllFailed()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Generic Failed Alert Banner

    private var failedAlertBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.red)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(state.failedCount) download\(state.failedCount == 1 ? "" : "s") failed")
                    .font(.system(size: 13, weight: .semibold))
                Text("Click Retry Failed to resume downloads.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                state.retryAllFailed()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry Failed")
                }
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.blue.gradient.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)
            }

            VStack(spacing: 6) {
                Text("No Downloads in Queue")
                    .font(.title3.bold())
                Text("Videos and playlists you download will appear here with live speed and progress.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            Button {
                state.section = .new
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Start a New Download")
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Theme.primaryAccent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Job Card

struct JobCard: View {
    @ObservedObject var job: DownloadJob
    @EnvironmentObject var state: AppState

    @State private var isHovered = false

    private var isBotError: Bool {
        CookieManager.isBotOrAuthError(job.errorText ?? "")
    }

    var body: some View {
        HStack(spacing: 14) {
            // Media Type Icon Badge
            mediaIconBadge

            // Details and Progress
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(job.entry.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                    Spacer()

                    statusBadge
                }

                // Sleek Custom Progress Bar
                if job.state != .queued && !job.isFinished || job.state == .done {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.08))
                                .frame(height: 5)

                            Capsule()
                                .fill(progressBarGradient)
                                .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(job.progress))), height: 5)
                                .animation(.easeOut(duration: 0.2), value: job.progress)
                        }
                    }
                    .frame(height: 5)
                }

                // Subtitle Info Row (Speed, Status, Error)
                HStack(spacing: 8) {
                    Text(job.statusText)
                        .font(.caption)
                        .foregroundStyle(statusColor)

                    if !job.speedText.isEmpty {
                        Text("•  \(job.speedText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                // Error box
                if let error = job.errorText {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                            .lineLimit(2)
                            .textSelection(.enabled)

                        if isBotError {
                            Button {
                                state.openSettings(tab: .cookies)
                            } label: {
                                Text("Open Settings → Cookies to Fix")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.orange)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            // Action Button
            actionButton
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isHovered ? Theme.primaryAccent.opacity(0.2) : Theme.cardBorder, lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var mediaIconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    job.mode == .audio
                        ? Theme.accentGradient.opacity(0.15)
                        : Theme.accentBlueGradient.opacity(0.15)
                )
                .frame(width: 38, height: 38)

            VStack(spacing: 1) {
                Image(systemName: job.mode == .audio ? "waveform" : "film.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(
                        job.mode == .audio
                            ? Theme.primaryAccent
                            : Color.blue
                    )
                Text(job.mode == .audio ? job.audioQuality.shortLabel : job.videoQuality.shortLabel)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(job.mode == .audio ? Theme.primaryAccent : Color.blue)
            }
        }
    }

    private var progressBarGradient: LinearGradient {
        if job.state == .done {
            return LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
        } else if job.state == .failed {
            return LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
        }
        return Theme.accentBlueGradient
    }

    private var statusBadge: some View {
        Group {
            switch job.state {
            case .done:
                Label("Done", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed:
                Label("Failed", systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
            case .running:
                HStack(spacing: 4) {
                    ProgressView().controlSize(.mini)
                    Text("\(Int(job.progress * 100))%")
                        .foregroundStyle(.blue)
                }
            case .processing:
                HStack(spacing: 4) {
                    ProgressView().controlSize(.mini)
                    Text("Processing")
                        .foregroundStyle(.blue)
                }
            case .queued:
                Label("Queued", systemImage: "clock")
                    .foregroundStyle(.secondary)
            case .cancelled:
                Label("Cancelled", systemImage: "xmark.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption2.weight(.medium))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.primary.opacity(0.04))
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch job.state {
        case .failed: return .red
        case .done: return .green
        default: return .secondary
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch job.state {
        case .queued, .running, .processing:
            Button {
                state.cancel(job)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Cancel download")

        case .failed, .cancelled:
            Button {
                state.retry(job)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.primaryAccent)
                    .frame(width: 28, height: 28)
                    .background(Theme.primaryAccent.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Retry download")

        case .done:
            Button {
                job.revealInFinder()
            } label: {
                Image(systemName: "folder")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Show file in Finder")
        }
    }
}
