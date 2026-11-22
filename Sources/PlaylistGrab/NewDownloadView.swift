import SwiftUI
import AppKit

struct NewDownloadView: View {
    @EnvironmentObject var state: AppState

    @AppStorage("downloadFolder") private var downloadFolder = AppDefaults.downloadFolder
    @AppStorage("subsEnabled") private var subsEnabled = false
    @AppStorage("subLang") private var subLang = "en"
    @AppStorage("cookieSource") private var cookieSource = CookieSourceType.browser.rawValue

    @State private var filterQuery = ""
    @State private var rangeQuery = ""

    var body: some View {
        VStack(spacing: 0) {
            heroControlCard
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()
                .opacity(0.6)

            resultsContent

            if state.hasSource {
                bottomBar
            }
        }
        .navigationTitle("New Download")
        .onAppear {
            state.checkExistingDownloads(in: downloadFolder)
        }
        .onChange(of: downloadFolder) { newFolder in
            state.checkExistingDownloads(in: newFolder)
        }
    }

    // MARK: - Hero Top Card

    private var heroControlCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // URL Input bar
            HStack(spacing: 10) {
                Image(systemName: "link.badge.plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.primaryAccent)
                    .padding(.leading, 6)

                TextField("Paste YouTube video, playlist, or album link…", text: $state.urlText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .regular))
                    .onSubmit { state.fetch() }

                if !state.urlText.isEmpty {
                    Button {
                        state.urlText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    if let text = NSPasteboard.general.string(forType: .string) {
                        state.urlText = text.trimmed
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 11))
                        Text("Paste")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Paste from clipboard")

                Button {
                    state.fetch()
                } label: {
                    HStack(spacing: 6) {
                        if state.isFetching {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 13, weight: .bold))
                        }
                        Text(state.isFetching ? "Fetching…" : "Fetch")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        state.urlText.trimmed.isEmpty || state.isFetching
                            ? AnyShapeStyle(Color.primary.opacity(0.08))
                            : AnyShapeStyle(Theme.accentGradient)
                    )
                    .foregroundStyle(
                        state.urlText.trimmed.isEmpty || state.isFetching
                            ? Color.secondary
                            : Color.white
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(
                        color: state.urlText.trimmed.isEmpty || state.isFetching
                            ? .clear
                            : Theme.primaryAccent.opacity(0.35),
                        radius: 4,
                        y: 1
                    )
                }
                .buttonStyle(.plain)
                .disabled(state.urlText.trimmed.isEmpty || state.isFetching)
            }
            .padding(8)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Theme.cardBorder, lineWidth: 1)
            )

            // Configuration Bar
            HStack(spacing: 10) {
                // Media Type Mode Switcher
                HStack(spacing: 2) {
                    modeButton(title: "Video", icon: "film", mode: .video)
                    modeButton(title: "Audio (MP3)", icon: "waveform", mode: .audio)
                }
                .padding(3)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Quality Selector (Video resolution or Audio bitrate)
                if state.mode == .video {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles.tv")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.primaryAccent)
                        Picker("Quality", selection: $state.videoQuality) {
                            ForEach(VideoQuality.allCases) { q in
                                Text(q.displayName).tag(q)
                            }
                        }
                        .labelsHidden()
                        .controlSize(.small)
                        .frame(width: 135)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.cardBorder, lineWidth: 1))
                    .help("Download quality for all video files")
                } else {
                    HStack(spacing: 5) {
                        Image(systemName: "waveform")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.primaryAccent)
                        Picker("Quality", selection: $state.audioQuality) {
                            ForEach(AudioQuality.allCases) { q in
                                Text(q.displayName).tag(q)
                            }
                        }
                        .labelsHidden()
                        .controlSize(.small)
                        .frame(width: 140)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.cardBorder, lineWidth: 1))
                    .help("Audio bitrate for extracted MP3s")
                }

                // Subtitle toggle & picker (video only)
                if state.mode == .video {
                    HStack(spacing: 6) {
                        Toggle(isOn: $subsEnabled) {
                            Label("Subtitles", systemImage: "captions.bubble.fill")
                                .font(.system(size: 12))
                        }
                        .toggleStyle(.checkbox)

                        if subsEnabled {
                            Picker("", selection: $subLang) {
                                ForEach(SubtitleLanguage.all) { lang in
                                    Text(lang.name).tag(lang.code)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 130)
                            .controlSize(.small)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Spacer()

                // Cookie Indicator Pill
                Button {
                    state.openSettings(tab: .cookies)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: CookieManager.isConfiguredAndActive ? "shield.checkmark" : "shield.slash")
                            .font(.system(size: 11))
                            .foregroundStyle(CookieManager.isConfiguredAndActive ? Color.green : Color.orange)
                        Text(CookieManager.currentStatusSummary)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.cardBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("Authentication cookies for YouTube bot protection. Click to change.")

                // Destination Folder Bar
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.blue)
                    let resolved = state.hasSource && state.sourceIsPlaylist
                        ? state.resolvedDestination(forFolder: downloadFolder).path
                        : downloadFolder
                    Text(displayPath(resolved))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Button("Change…") {
                        if let chosen = FolderPicker.choose(startingAt: downloadFolder) {
                            downloadFolder = chosen
                            state.checkExistingDownloads(in: chosen)
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.cardBorder, lineWidth: 1))
            }
        }
        .asCard(padding: 12, cornerRadius: 12)
    }

    private func modeButton(title: String, icon: String, mode: MediaMode) -> some View {
        Button {
            state.mode = mode
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                state.mode == mode
                    ? Color(nsColor: .controlBackgroundColor)
                    : Color.clear
            )
            .foregroundStyle(state.mode == mode ? .primary : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: state.mode == mode ? Color.black.opacity(0.08) : Color.clear, radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Middle Content Area

    @ViewBuilder
    private var resultsContent: some View {
        if state.isFetching {
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                VStack(spacing: 4) {
                    Text("Inspecting Media…")
                        .font(.headline)
                    Text("Fetching track titles, durations, and formats.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = state.fetchError {
            errorView(error: error)
        } else if !state.hasSource {
            welcomeEmptyState
        } else {
            fetchedListArea
        }
    }

    // MARK: - Error View with Bot Protection helper

    private func errorView(error: String) -> some View {
        let isBot = CookieManager.isBotOrAuthError(error)

        return VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill((isBot ? Color.orange : Color.red).opacity(0.12))
                    .frame(width: 64, height: 64)

                Image(systemName: isBot ? "shield.slash.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(isBot ? Color.orange : Color.red)
            }

            VStack(spacing: 6) {
                Text(isBot ? "YouTube Bot Verification Required" : "Unable to Read Link")
                    .font(.title3.bold())

                Text(error)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 480)
                    .textSelection(.enabled)
            }

            HStack(spacing: 12) {
                if isBot {
                    Button {
                        state.openSettings(tab: .cookies)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "gearshape.fill")
                            Text("Configure Browser Cookies")
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Theme.accentGradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    state.fetch()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Welcome Empty State

    private var welcomeEmptyState: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Theme.accentGradient.opacity(0.12))
                    .frame(width: 88, height: 88)
                Image(systemName: "play.square.stack.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.primaryAccent)
            }

            VStack(spacing: 6) {
                Text("Ready to Download")
                    .font(.title2.bold())
                Text("Paste any YouTube video or playlist link above to inspect and download.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
            }

            // Feature Highlights
            HStack(spacing: 12) {
                featureCard(
                    icon: "sparkles",
                    title: "Playlists & Albums",
                    desc: "Grab hundreds of tracks in sequence"
                )
                featureCard(
                    icon: "waveform",
                    title: "Audio Extraction",
                    desc: "High quality MP3 with ID3 tags"
                )
                featureCard(
                    icon: "shield.checkmark",
                    title: "Bot Guard",
                    desc: "Bypass verification with cookies"
                )
                featureCard(
                    icon: "arrow.clockwise",
                    title: "Smart Skip",
                    desc: "Skips already downloaded files"
                )
            }
            .frame(maxWidth: 680)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func featureCard(icon: String, title: String, desc: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.primaryAccent)
                .frame(width: 32, height: 32)
                .background(Theme.primaryAccent.opacity(0.1))
                .clipShape(Circle())

            Text(title)
                .font(.system(size: 11, weight: .semibold))

            Text(desc)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.cardBorder, lineWidth: 1))
    }

    // MARK: - Fetched Media List Area

    private var fetchedListArea: some View {
        VStack(spacing: 0) {
            // Source Info & Quick Action Banner
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.sourceTitle)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(state.sourceIsPlaylist ? "\(state.entries.count) Videos in Playlist" : "Single Video")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)

                        if state.downloadedEntriesCount > 0 {
                            Text("•  \(state.downloadedEntriesCount) already saved")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.green)
                        }
                    }
                }

                Spacer()

                // Filter search box
                if state.entries.count > 4 {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        TextField("Filter titles…", text: $filterQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                            .frame(width: 130)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.cardBorder, lineWidth: 1))
                }

                // Batch Selection buttons (for single video or quick actions)
                if !state.sourceIsPlaylist {
                    HStack(spacing: 6) {
                        Button("All") { state.setAllSelected(true) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        Button("None") { state.setAllSelected(false) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))

            if state.sourceIsPlaylist {
                Divider()
                    .opacity(0.4)
                rangeSelectionBar
            }

            Divider()
                .opacity(0.6)

            // Video Cards ScrollView
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(state.entries.indices, id: \.self) { index in
                        if filterQuery.isEmpty || state.entries[index].title.localizedCaseInsensitiveContains(filterQuery) {
                            VideoEntryRow(index: index, entry: $state.entries[index], isPlaylist: state.sourceIsPlaylist)
                        }
                    }
                }
                .padding(14)
            }
        }
    }

    // MARK: - Range Selection Bar

    private enum RangeApplyMode {
        case selectOnly, add, remove
    }

    private func applyRange(mode: RangeApplyMode) {
        let matched = RangeParser.parse(rangeQuery, maxCount: state.entries.count)
        guard !matched.isEmpty else { return }
        switch mode {
        case .selectOnly:
            state.selectRangeOnly(matched)
        case .add:
            state.addRangeToSelection(matched)
        case .remove:
            state.removeRangeFromSelection(matched)
        }
    }

    private var rangeSelectionBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "list.number")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.primaryAccent)
                Text("Select Range:")
                    .font(.system(size: 11, weight: .semibold))
            }

            HStack(spacing: 5) {
                TextField("e.g. 2-9, 14, 15-23", text: $rangeQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .onSubmit {
                        applyRange(mode: .selectOnly)
                    }

                if !rangeQuery.isEmpty {
                    Button {
                        rangeQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(minWidth: 160, maxWidth: 210)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.cardBorder, lineWidth: 1))

            let matched = RangeParser.parse(rangeQuery, maxCount: state.entries.count)

            if !rangeQuery.trimmed.isEmpty {
                Text("\(matched.count) matching")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(matched.isEmpty ? .secondary : Theme.primaryAccent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.primaryAccent.opacity(0.1))
                    .clipShape(Capsule())
            }

            Button {
                applyRange(mode: .selectOnly)
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle")
                    Text("Select Only")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.primaryAccent)
            .controlSize(.small)
            .disabled(matched.isEmpty)
            .help("Select ONLY the specified videos and uncheck the rest")

            Button {
                applyRange(mode: .add)
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "plus")
                    Text("Add")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(matched.isEmpty)
            .help("Add the specified videos to your current selection")

            Button {
                applyRange(mode: .remove)
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "minus")
                    Text("Deselect")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(matched.isEmpty)
            .help("Uncheck the specified videos so they won't be downloaded")

            Spacer()

            // Presets
            HStack(spacing: 4) {
                Button("Invert") {
                    state.invertSelection()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Invert current selection")

                if state.downloadedEntriesCount > 0 {
                    Button("Missing") {
                        state.selectMissingOnly()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Select only videos not yet downloaded")
                }

                Button("All") {
                    state.setAllSelected(true)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("None") {
                    state.setAllSelected(false)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
    }

    // MARK: - Bottom Floating Action Dock

    private var bottomBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(state.selectedCount) of \(state.entries.count) Selected")
                        .font(.system(size: 13, weight: .semibold))

                    Text("•")
                        .foregroundStyle(.tertiary)

                    Text(state.mode == .video ? state.videoQuality.displayName : state.audioQuality.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.primaryAccent)
                }

                if state.downloadedEntriesCount > 0 {
                    Text("\(state.downloadedEntriesCount) previously downloaded")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                state.downloadSelected()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(downloadButtonTitle)
                        .font(.system(size: 13, weight: .bold))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    state.selectedCount == 0
                        ? AnyShapeStyle(Color.primary.opacity(0.1))
                        : AnyShapeStyle(Theme.accentGradient)
                )
                .foregroundStyle(state.selectedCount == 0 ? Color.secondary : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .shadow(
                    color: state.selectedCount == 0 ? .clear : Theme.primaryAccent.opacity(0.4),
                    radius: 6,
                    y: 2
                )
            }
            .buttonStyle(.plain)
            .disabled(state.selectedCount == 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Theme.cardBorder),
            alignment: .top
        )
    }

    private var downloadButtonTitle: String {
        if state.downloadedEntriesCount > 0 && state.selectedCount == state.missingEntriesCount {
            return "Download \(state.selectedCount) Missing"
        }
        if state.entries.count == 1 { return "Download Video" }
        return "Download \(state.selectedCount) Videos"
    }

    private func displayPath(_ path: String) -> String {
        (path as NSString).abbreviatingWithTildeInPath
    }
}

// MARK: - Video Entry Row Card

struct VideoEntryRow: View {
    @EnvironmentObject var state: AppState
    let index: Int
    @Binding var entry: VideoEntry
    let isPlaylist: Bool

    @State private var isHovered = false

    private func toggleSelection() {
        let shiftHeld = NSEvent.modifierFlags.contains(.shift)
        state.toggleEntrySelection(at: index, shiftHeld: shiftHeld)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                toggleSelection()
            } label: {
                Image(systemName: entry.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(entry.isSelected ? Theme.primaryAccent : .secondary)
            }
            .buttonStyle(.plain)

            if isPlaylist {
                Text(String(format: "%02d", entry.index))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(width: 24, alignment: .center)
            }

            // Title
            Text(entry.title)
                .font(.system(size: 13, weight: .regular))
                .lineLimit(1)
                .foregroundStyle(entry.isDownloaded ? .secondary : .primary)

            if entry.isDownloaded {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                    Text("Downloaded")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.12))
                .clipShape(Capsule())
            }

            Spacer()

            // Duration
            if let duration = entry.duration, duration > 0 {
                Text(Fmt.duration(duration))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(
                    isHovered
                        ? Color.primary.opacity(0.05)
                        : (entry.isSelected ? Color(nsColor: .controlBackgroundColor).opacity(0.8) : Color.clear)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(
                    entry.isSelected ? Theme.cardBorder : Color.clear,
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            toggleSelection()
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
