import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var tools: ToolManager

    @AppStorage("maxParallel") private var maxParallel = 3
    @AppStorage("downloadFolder") private var downloadFolder = AppDefaults.downloadFolder
    @AppStorage("videoFormat") private var videoFormat = VideoFormatPreference.compatibleMP4.rawValue
    @AppStorage("autoUpdateYTDLP") private var autoUpdate = true

    var body: some View {
        Form {
            Section("Downloads") {
                Stepper(value: $maxParallel, in: 1...10) {
                    Text("Parallel downloads: \(maxParallel)")
                }
                if maxParallel > 5 {
                    Text("Very high values can get you slowed down or temporarily blocked by YouTube.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Save to") {
                    HStack {
                        Text((downloadFolder as NSString).abbreviatingWithTildeInPath)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Choose…") {
                            if let chosen = FolderPicker.choose(startingAt: downloadFolder) {
                                downloadFolder = chosen
                            }
                        }
                    }
                }

                Picker("Video format", selection: $videoFormat) {
                    ForEach(VideoFormatPreference.allCases) { option in
                        Text(option.label).tag(option.rawValue)
                    }
                }
                Text("MP4 plays everywhere on a Mac (QuickTime, iPhone, iMovie) but YouTube only offers it up to 1080p. MKV keeps the best quality; play it with VLC or IINA.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Download engine") {
                LabeledContent("yt-dlp", value: tools.ytdlpVersion)
                LabeledContent("ffmpeg", value: tools.hasFFmpeg ? "Found" : "Missing")
                LabeledContent("Deno", value: tools.hasDeno ? "Found" : "Missing")

                Toggle("Update yt-dlp automatically at launch", isOn: $autoUpdate)

                HStack {
                    Button("Check for Updates") {
                        Task { await tools.updateYTDLP() }
                    }
                    .disabled(tools.isUpdating)

                    Button("Reset to Bundled Version") {
                        Task { await tools.resetYTDLP() }
                    }
                    .disabled(tools.isUpdating)

                    if tools.isUpdating {
                        ProgressView().controlSize(.small)
                    }
                }
                if !tools.updateStatus.isEmpty {
                    Text(tools.updateStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            Section("About") {
                Text("PlaylistGrab is free, open-source software (MIT License). It uses yt-dlp, Deno and ffmpeg; their licenses are included in the app’s Resources folder. Only download content you own or have permission to save.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 540)
        .padding(.vertical, 8)
    }
}
