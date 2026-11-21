import SwiftUI
import AppKit

struct NewDownloadView: View {
    @EnvironmentObject var state: AppState

    @AppStorage("downloadFolder") private var downloadFolder = AppDefaults.downloadFolder
    @AppStorage("subsEnabled") private var subsEnabled = false
    @AppStorage("subLang") private var subLang = "en"

    @State private var filterQuery = ""

    var body: some View {
        VStack(spacing: 0) {
            heroControlCard
                .padding(16)

            Divider()

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
        VStack(alignment: .leading, spacing: 14) {
            // URL Input bar
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.primaryAccent)
                    .padding(.leading, 6)

                TextField("Paste YouTube video or playlist link…", text: $state.urlText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit { state.fetch() }

                if !state.urlText.isEmpty {
                    Button {
                        state.urlText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
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
                        Text("Paste")
                    }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                Button {
                    state.fetch()
                } label: {
                    HStack(spacing: 4) {
                        if state.isFetching {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.right")
                                .font(.caption.weight(.bold))
                        }
                        Text("Fetch")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        state.urlText.trimmed.isEmpty || state.isFetching
                            ? Color.primary.opacity(0.1)
                            : Theme.primaryAccent
                    )
                    .foregroundStyle(
                        state.urlText.trimmed.isEmpty || state.isFetching
                            ? Color.secondary
                            : Color.white
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 7))
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
            HStack(spacing: 12) {
                // Media Type Mode Switcher
                HStack(spacing: 0) {
                    modeButton(title: "Video", icon: "film", mode: .video)
                    modeButton(title: "Audio (MP3)", icon: "waveform", mode: .audio)
                }
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Subtitle toggle & picker
                HStack(spacing: 6) {
                    Toggle(isOn: $subsEnabled) {
                        Label("Subtitles", systemImage: "captions.bubble.fill")
                            .font(.subheadline)
                    }
                    .toggleStyle(.checkbox)
                    .disabled(state.mode == .audio)

                    if subsEnabled && state.mode != .audio {
                        Picker("", selection: $subLang) {
                            ForEach(SubtitleLanguage.all) { lang in
                                Text(lang.name).tag(lang.code)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 140)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer()

                // Destination Folder Bar
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.blue.gradient)
                    let resolved = state.hasSource && state.sourceIsPlaylist
                        ? state.resolvedDestination(forFolder: downloadFolder).path
                        : downloadFolder
                    Text(displayPath(resolved))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Button("Change…") {
                        if let chosen = FolderPicker.choose(startingAt: downloadFolder) {
                            downloadFolder = chosen
                            state.checkExistingDownloads(in: chosen)
                        }
                    }
                    .font(.caption.weight(.medium))
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .asCard(padding: 14, cornerRadius: 12)
    }

    private func modeButton(title: String, icon: String, mode: MediaMode) -> some View {
        Button {
            state.mode = mode
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                state.mode == mode
                    ? Color(nsColor: .controlBackgroundColor)
                    : Color.clear
            )
            .foregroundStyle(state.mode == mode ? .primary : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .shadow(color: state.mode == mode ? Color.black.opacity(0.06) : Color.clear, radius: 2, y: 1)
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
                    Text("Fetching Media Information…")
                        .font(.headline)
                    Text("Reading video titles, durations and playlist tracks.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = state.fetchError {
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.orange)
                Text("Unable to Read Link")
                    .font(.headline)
                Text(error)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 440)
                    .textSelection(.enabled)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !state.hasSource {
            welcomeEmptyState
        } else {
            fetchedListArea
        }
    }

    // MARK: - Welcome Empty State

    private var welcomeEmptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Theme.accentGradient.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "play.square.stack.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Theme.primaryAccent)
            }

            VStack(spacing: 6) {
                Text("Ready to Download")
                    .font(.title2.bold())
                Text("Paste any YouTube video or playlist link above to inspect and download.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            HStack(spacing: 12) {
                featurePill(icon: "sparkles", text: "Full Playlists & Singles")
                featurePill(icon: "waveform", text: "Video or Audio MP3")
                featurePill(icon: "captions.bubble", text: "Auto Subtitles")
                featurePill(icon: "arrow.clockwise", text: "Resume & Skip Existing")
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func featurePill(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Theme.primaryAccent)
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.04))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Theme.cardBorder, lineWidth: 1))
    }

    // MARK: - Fetched Media List Area

    private var filteredEntries: [Binding<VideoEntry>] {
        if filterQuery.trimmed.isEmpty {
            return $state.entries
        }
        let q = filterQuery.lowercased()
        return $state.entries.filter { $0.wrappedValue.title.lowercased().contains(q) }
    }

    private var fetchedListArea: some View {
        VStack(spacing: 0) {
            // Source Info & Quick Action Banner
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.sourceTitle)
                        .font(.headline)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(state.sourceIsPlaylist ? "\(state.entries.count) Videos" : "Single Video")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        if state.downloadedEntriesCount > 0 {
                            Text("•  \(state.downloadedEntriesCount) already in folder")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }

                Spacer()

                // Filter search box if more than 6 videos
                if state.entries.count > 6 {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Filter titles…", text: $filterQuery)
                            .textFieldStyle(.plain)
                            .font(.caption)
                            .frame(width: 120)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.cardBorder, lineWidth: 1))
                }

                // Batch Selection buttons
                HStack(spacing: 6) {
                    if state.downloadedEntriesCount > 0 {
                        Button("Select Missing") { state.selectMissingOnly() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    Button("All") { state.setAllSelected(true) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Button("None") { state.setAllSelected(false) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

            Divider()

            // Custom Styled Video Cards ScrollView
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(filteredEntries) { $entry in
                        VideoEntryRow(entry: $entry, isPlaylist: state.sourceIsPlaylist)
                    }
                }
                .padding(12)
            }
        }
    }

    // MARK: - Bottom Floating Action Dock

    private var bottomBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(state.selectedCount) of \(state.entries.count) Selected")
                    .font(.subheadline.weight(.semibold))

                if state.downloadedEntriesCount > 0 {
                    Text("\(state.downloadedEntriesCount) previously downloaded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                state.downloadSelected()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.headline)
                    Text(downloadButtonTitle)
                        .font(.subheadline.weight(.bold))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(
                    state.selectedCount == 0
                        ? Color.primary.opacity(0.1)
                        : Theme.primaryAccent
                )
                .foregroundStyle(state.selectedCount == 0 ? Color.secondary : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .shadow(
                    color: state.selectedCount == 0 ? .clear : Theme.primaryAccent.opacity(0.35),
                    radius: 5,
                    y: 2
                )
            }
            .buttonStyle(.plain)
            .disabled(state.selectedCount == 0)
        }
        .padding(.horizontal, 18)
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
        if state.entries.count == 1 { return "Download" }
        return "Download \(state.selectedCount) Videos"
    }

    private func displayPath(_ path: String) -> String {
        (path as NSString).abbreviatingWithTildeInPath
    }
}

// MARK: - Video Entry Row Card

struct VideoEntryRow: View {
    @Binding var entry: VideoEntry
    let isPlaylist: Bool

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                entry.isSelected.toggle()
            } label: {
                Image(systemName: entry.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(entry.isSelected ? Theme.primaryAccent : .secondary)
            }
            .buttonStyle(.plain)

            if isPlaylist {
                Text(String(format: "%02d", entry.index))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
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
                        .font(.caption2.weight(.medium))
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
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isHovered
                        ? Color.primary.opacity(0.05)
                        : (entry.isSelected ? Color(nsColor: .controlBackgroundColor).opacity(0.7) : Color.clear)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    entry.isSelected ? Theme.cardBorder : Color.clear,
                    lineWidth: 1
                )
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
