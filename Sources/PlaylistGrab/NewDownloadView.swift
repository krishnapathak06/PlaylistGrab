import SwiftUI
import AppKit

struct NewDownloadView: View {
    @EnvironmentObject var state: AppState

    @AppStorage("downloadFolder") private var downloadFolder = AppDefaults.downloadFolder
    @AppStorage("subsEnabled") private var subsEnabled = false
    @AppStorage("subLang") private var subLang = "en"

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            results
            if state.hasSource {
                Divider()
                footer
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

    // MARK: - Top controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                TextField("Paste a video or playlist link", text: $state.urlText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { state.fetch() }

                Button {
                    if let text = NSPasteboard.general.string(forType: .string) {
                        state.urlText = text.trimmed
                    }
                } label: {
                    Image(systemName: "doc.on.clipboard")
                }
                .help("Paste from clipboard")

                Button("Fetch") { state.fetch() }
                    .buttonStyle(.borderedProminent)
                    .disabled(state.urlText.trimmed.isEmpty || state.isFetching)
            }

            HStack(spacing: 16) {
                Picker("Type", selection: $state.mode) {
                    ForEach(MediaMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 230)

                Toggle("Subtitles", isOn: $subsEnabled)
                    .disabled(state.mode == .audio)

                Picker("Language", selection: $subLang) {
                    ForEach(SubtitleLanguage.all) { language in
                        Text(language.name).tag(language.code)
                    }
                }
                .labelsHidden()
                .frame(width: 170)
                .disabled(state.mode == .audio || !subsEnabled)

                Spacer()
            }

            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                let resolved = state.hasSource && state.sourceIsPlaylist
                    ? state.resolvedDestination(forFolder: downloadFolder).path
                    : downloadFolder
                Text(displayPath(resolved))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Button("Change…") {
                    if let chosen = FolderPicker.choose(startingAt: downloadFolder) {
                        downloadFolder = chosen
                        state.checkExistingDownloads(in: chosen)
                    }
                }
                Spacer()
            }
        }
        .padding(20)
    }

    // MARK: - Middle

    @ViewBuilder
    private var results: some View {
        if state.isFetching {
            VStack(spacing: 12) {
                ProgressView()
                Text("Reading link…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = state.fetchError {
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 30))
                    .foregroundStyle(.orange)
                Text(error)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 460)
                    .textSelection(.enabled)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !state.hasSource {
            VStack(spacing: 10) {
                Image(systemName: "arrow.down.to.line.compact")
                    .font(.system(size: 36))
                    .foregroundStyle(.tertiary)
                Text("Paste a link to a video or playlist, then press Fetch.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                HStack {
                    Text(state.sourceTitle)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(state.sourceIsPlaylist ? "\(state.entries.count) videos" : "Single video")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

                List {
                    ForEach($state.entries) { $entry in
                        HStack(spacing: 10) {
                            Toggle("", isOn: $entry.isSelected)
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                            if state.sourceIsPlaylist {
                                Text(String(entry.index))
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .frame(minWidth: 28, alignment: .trailing)
                            }
                            Text(entry.title)
                                .lineLimit(1)
                                .foregroundStyle(entry.isDownloaded ? .secondary : .primary)

                            if entry.isDownloaded {
                                HStack(spacing: 3) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("Downloaded")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.12))
                                .clipShape(Capsule())
                            }

                            Spacer()
                            Text(Fmt.duration(entry.duration))
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            if state.downloadedEntriesCount > 0 {
                Button("Select Missing") { state.selectMissingOnly() }
            }
            Button("Select All") { state.setAllSelected(true) }
            Button("Select None") { state.setAllSelected(false) }
            Spacer()
            if state.downloadedEntriesCount > 0 {
                Text("\(state.downloadedEntriesCount) downloaded · \(state.selectedCount) of \(state.missingEntriesCount) missing selected")
                    .foregroundStyle(.secondary)
            } else {
                Text("\(state.selectedCount) of \(state.entries.count) selected")
                    .foregroundStyle(.secondary)
            }
            Button {
                state.downloadSelected()
            } label: {
                Text(downloadButtonTitle)
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(state.selectedCount == 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var downloadButtonTitle: String {
        if state.downloadedEntriesCount > 0 && state.selectedCount == state.missingEntriesCount {
            return "Download \(state.selectedCount) Missing"
        }
        if state.entries.count == 1 { return "Download" }
        return "Download \(state.selectedCount)"
    }

    private func displayPath(_ path: String) -> String {
        (path as NSString).abbreviatingWithTildeInPath
    }
}

@MainActor
enum FolderPicker {
    static func choose(startingAt path: String) -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.directoryURL = URL(fileURLWithPath: path, isDirectory: true)
        return panel.runModal() == .OK ? panel.url?.path : nil
    }
}
