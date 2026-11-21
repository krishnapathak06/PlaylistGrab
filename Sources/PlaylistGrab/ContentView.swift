import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var tools: ToolManager

    @AppStorage("cookieSource") private var cookieSource = CookieSourceType.browser.rawValue
    @AppStorage("cookieBrowser") private var cookieBrowser = SupportedBrowser.chrome.rawValue

    var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 210, ideal: 235, max: 280)
        } detail: {
            ZStack {
                Theme.surfaceBackground
                    .ignoresSafeArea()

                switch state.section ?? .new {
                case .new:
                    NewDownloadView()
                case .downloads:
                    DownloadsView()
                }
            }
        }
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // App Title Header
            appBrandHeader
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 12)
                .opacity(0.6)

            // Navigation items
            VStack(spacing: 4) {
                sidebarButton(
                    section: .new,
                    title: "New Download",
                    icon: "plus.circle.fill",
                    gradient: Theme.accentGradient
                )

                sidebarButton(
                    section: .downloads,
                    title: "Downloads",
                    icon: "arrow.down.circle.fill",
                    gradient: Theme.accentBlueGradient,
                    badgeCount: state.activeCount,
                    hasFailed: state.hasFailedJobs
                )
            }
            .padding(.horizontal, 10)
            .padding(.top, 12)

            Spacer()

            // Quick Cookie Status Widget
            cookieStatusWidget
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            // Engine status footer
            engineFooter
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .background(.ultraThinMaterial)
    }

    private var appBrandHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.accentGradient)
                    .frame(width: 28, height: 28)
                    .shadow(color: Theme.primaryAccent.opacity(0.35), radius: 4, y: 1)

                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("PlaylistGrab")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text("Fast YouTube Downloader")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func sidebarButton(
        section: SidebarSection,
        title: String,
        icon: String,
        gradient: LinearGradient,
        badgeCount: Int = 0,
        hasFailed: Bool = false
    ) -> some View {
        let isSelected = state.section == section

        return Button {
            state.section = section
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? AnyShapeStyle(gradient) : AnyShapeStyle(Color.secondary))
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)

                Spacer()

                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.blue))
                } else if hasFailed {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sidebar Cookie Status Card

    private var cookieStatusWidget: some View {
        Button {
            CookieManager.openSettings()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: CookieManager.isConfiguredAndActive ? "shield.checkmark.fill" : "shield.slash.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(CookieManager.isConfiguredAndActive ? .green : .orange)

                VStack(alignment: .leading, spacing: 1) {
                    Text("YouTube Bot Guard")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text(CookieManager.currentStatusSummary)
                        .font(.system(size: 10))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Theme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help("Click to configure cookies and bypass YouTube bot protection")
    }

    // MARK: - Engine Footer

    private var engineFooter: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tools.ytdlpVersion != "error" && tools.ytdlpVersion != "not found" ? Color.green : Color.orange)
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 1) {
                Text("yt-dlp Core")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(tools.ytdlpVersion)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            if tools.isUpdating {
                ProgressView().controlSize(.mini)
            } else {
                Button {
                    CookieManager.openSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Theme.cardBorder, lineWidth: 1)
        )
    }
}
