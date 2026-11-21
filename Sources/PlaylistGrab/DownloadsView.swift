import SwiftUI
import AppKit

struct DownloadsView: View {
    @EnvironmentObject var state: AppState
    @AppStorage("downloadFolder") private var downloadFolder = AppDefaults.downloadFolder

    var body: some View {
        Group {
            if state.jobs.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("Nothing downloading yet.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    if state.hasFailedJobs {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                            Text("\(state.failedCount) download\(state.failedCount == 1 ? "" : "s") failed")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Button {
                                state.retryAllFailed()
                            } label: {
                                Label("Retry Failed", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                    }

                    List(state.jobs) { job in
                        JobRow(job: job)
                            .padding(.vertical, 4)
                    }
                    .listStyle(.inset)
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
                .help("Open the download folder")

                Button {
                    state.clearFinished()
                } label: {
                    Label("Clear Finished", systemImage: "trash")
                }
                .help("Remove finished, failed and cancelled items from the list")
                .disabled(!state.hasFinishedJobs || state.revision < 0)
            }
        }
    }
}

struct JobRow: View {
    @ObservedObject var job: DownloadJob
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(job.entry.title)
                    .lineLimit(1)

                if job.state != .queued && !job.isFinished || job.state == .done {
                    ProgressView(value: job.progress)
                }

                HStack(spacing: 6) {
                    Text(job.statusText)
                        .foregroundStyle(statusColor)
                    if !job.speedText.isEmpty {
                        Text("· \(job.speedText)")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)

                if let error = job.errorText {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
            }

            actionButton
        }
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
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
            .help("Cancel")
        case .failed, .cancelled:
            Button {
                state.retry(job)
            } label: {
                Image(systemName: "arrow.clockwise.circle.fill")
            }
            .buttonStyle(.borderless)
            .help("Retry (partial downloads are resumed)")
        case .done:
            Button {
                job.revealInFinder()
            } label: {
                Image(systemName: "magnifyingglass.circle.fill")
            }
            .buttonStyle(.borderless)
            .help("Show in Finder")
        }
    }
}
