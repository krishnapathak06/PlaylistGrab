import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var tools: ToolManager

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: $state.section) {
                    Section {
                        NavigationLink(value: SidebarSection.new) {
                            HStack(spacing: 10) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 22, height: 22)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Theme.accentGradient)
                                    )

                                Text("New Download")
                                    .fontWeight(.medium)
                            }
                            .padding(.vertical, 2)
                        }
                        .tag(SidebarSection.new)

                        NavigationLink(value: SidebarSection.downloads) {
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 22, height: 22)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Theme.accentBlueGradient)
                                    )

                                Text("Downloads")
                                    .fontWeight(.medium)

                                Spacer()

                                if state.activeCount > 0 {
                                    Text("\(state.activeCount)")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.blue))
                                } else if state.hasFailedJobs {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .tag(SidebarSection.downloads)
                    }
                }
                .listStyle(.sidebar)

                Spacer()

                // Sidebar footer with engine status
                engineFooter
                    .padding(12)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            switch state.section ?? .new {
            case .new:
                NewDownloadView()
            case .downloads:
                DownloadsView()
            }
        }
    }

    private var engineFooter: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tools.ytdlpVersion != "error" && tools.ytdlpVersion != "not found" ? Color.green : Color.orange)
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 1) {
                Text("Engine Ready")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Text("yt-dlp \(tools.ytdlpVersion)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            if tools.isUpdating {
                ProgressView().controlSize(.mini)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Theme.cardBorder, lineWidth: 1)
        )
    }
}
