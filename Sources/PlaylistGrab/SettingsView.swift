import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case cookies = "Cookies & Auth"
    case engine = "Engine"
    case about = "About"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .cookies: return "shield.checkmark"
        case .engine: return "cpu"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var tools: ToolManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: SettingsTab

    init(initialTab: SettingsTab = .general) {
        _selectedTab = State(initialValue: initialTab)
    }

    // General Settings
    @AppStorage("maxParallel") private var maxParallel = 3
    @AppStorage("downloadFolder") private var downloadFolder = AppDefaults.downloadFolder
    @AppStorage("videoFormat") private var videoFormat = VideoFormatPreference.compatibleMP4.rawValue
    @AppStorage("videoQuality") private var defaultVideoQuality = VideoQuality.q1080p.rawValue
    @AppStorage("audioQuality") private var defaultAudioQuality = AudioQuality.best.rawValue
    @AppStorage("autoUpdateYTDLP") private var autoUpdate = true

    // Cookies Settings
    @AppStorage("cookieSource") private var cookieSource = CookieSourceType.browser.rawValue
    @AppStorage("cookieBrowser") private var cookieBrowser = SupportedBrowser.chrome.rawValue
    @AppStorage("cookieFilePath") private var cookieFilePath = ""
    @AppStorage("cookieManualText") private var cookieManualText = ""

    @State private var manualSaveStatus = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header with Close Button
            HStack {
                Text("Settings")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Tab picker bar
            Picker("", selection: $selectedTab) {
                ForEach(SettingsTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.iconName).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .general:
                        generalSection
                    case .cookies:
                        cookiesSection
                    case .engine:
                        engineSection
                    case .about:
                        aboutSection
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 560, height: 480)
    }

    // MARK: - General Section

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Destination folder
            VStack(alignment: .leading, spacing: 6) {
                Text("Default Download Location")
                    .font(.system(size: 13, weight: .semibold))

                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.blue)
                    Text((downloadFolder as NSString).abbreviatingWithTildeInPath)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Choose Folder…") {
                        if let chosen = FolderPicker.choose(startingAt: downloadFolder) {
                            downloadFolder = chosen
                        }
                    }
                    .controlSize(.small)
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.cardBorder, lineWidth: 1))
            }

            // Parallel downloads
            VStack(alignment: .leading, spacing: 6) {
                Text("Concurrent Downloads")
                    .font(.system(size: 13, weight: .semibold))

                HStack {
                    Stepper(value: $maxParallel, in: 1...8) {
                        Text("\(maxParallel) parallel downloads")
                            .font(.system(size: 12))
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.cardBorder, lineWidth: 1))

                if maxParallel > 4 {
                    Text("Setting this higher than 4 may increase YouTube rate limits or trigger temporary IP throttling.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            // Default Video Quality
            VStack(alignment: .leading, spacing: 6) {
                Text("Default Video Quality")
                    .font(.system(size: 13, weight: .semibold))

                Picker("", selection: $defaultVideoQuality) {
                    ForEach(VideoQuality.allCases) { q in
                        Text(q.displayName).tag(q.rawValue)
                    }
                }
                .labelsHidden()

                Text("Videos will download up to this resolution by default. You can also adjust this directly on the New Download screen before starting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Default Audio Quality
            VStack(alignment: .leading, spacing: 6) {
                Text("Default Audio Quality")
                    .font(.system(size: 13, weight: .semibold))

                Picker("", selection: $defaultAudioQuality) {
                    ForEach(AudioQuality.allCases) { q in
                        Text(q.displayName).tag(q.rawValue)
                    }
                }
                .labelsHidden()
            }

            // Video Format
            VStack(alignment: .leading, spacing: 6) {
                Text("Preferred Video Format")
                    .font(.system(size: 13, weight: .semibold))

                Picker("", selection: $videoFormat) {
                    ForEach(VideoFormatPreference.allCases) { option in
                        Text(option.label).tag(option.rawValue)
                    }
                }
                .labelsHidden()

                Text("MP4 plays natively on Apple devices (QuickTime, iPhone, iPad) up to 1080p. MKV preserves the highest available resolution (4K / 8K) and best audio stream.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Cookies & Bot Authentication Section

    private var cookiesSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Explanation Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.accentGradient.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "shield.checkmark.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.primaryAccent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("YouTube Bot & Sign-in Protection")
                        .font(.system(size: 14, weight: .bold))
                    Text("Fixes the 'Sign in to confirm you’re not a bot' error by providing your YouTube session.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.cardBorder, lineWidth: 1))

            // Cookie Source Choice
            VStack(alignment: .leading, spacing: 10) {
                Text("Authentication Method")
                    .font(.system(size: 13, weight: .semibold))

                Picker("", selection: $cookieSource) {
                    ForEach(CookieSourceType.allCases) { type in
                        Text(type.label).tag(type.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            // Method-Specific Configuration
            let currentSource = CookieSourceType(rawValue: cookieSource) ?? .browser

            switch currentSource {
            case .browser:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Web Browser:")
                        .font(.system(size: 12, weight: .medium))

                    HStack {
                        Picker("", selection: $cookieBrowser) {
                            ForEach(SupportedBrowser.allCases) { browser in
                                Text(browser.displayName).tag(browser.rawValue)
                            }
                        }
                        .frame(width: 220)

                        Spacer()
                    }

                    Text("yt-dlp will automatically read your YouTube session from this browser when downloading. Make sure you are logged into YouTube in this browser.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            case .file:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Netscape cookies.txt file:")
                        .font(.system(size: 12, weight: .medium))

                    HStack {
                        Text(cookieFilePath.isEmpty ? "No file selected" : (cookieFilePath as NSString).lastPathComponent)
                            .font(.system(size: 12))
                            .foregroundStyle(cookieFilePath.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        Button("Browse…") {
                            if let chosen = FilePicker.chooseFile(allowedExtensions: ["txt", "cookies"]) {
                                cookieFilePath = chosen
                            }
                        }
                        .controlSize(.small)
                    }

                    Text("You can export cookies from your browser using extensions like 'Get cookies.txt LOCALLY' or 'Cookie-Editor'.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            case .manual:
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Paste Netscape / Raw Cookies:")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        if !manualSaveStatus.isEmpty {
                            Text(manualSaveStatus)
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                        }
                    }

                    TextEditor(text: $cookieManualText)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(height: 120)
                        .padding(4)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.cardBorder, lineWidth: 1))

                    HStack {
                        Button("Save Cookies") {
                            _ = CookieManager.buildArguments()
                            manualSaveStatus = "Saved!"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                manualSaveStatus = ""
                            }
                        }
                        .controlSize(.small)

                        if !cookieManualText.isEmpty {
                            Button("Clear") {
                                cookieManualText = ""
                            }
                            .controlSize(.small)
                        }

                        Spacer()
                    }
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            case .none:
                Text("Cookie authentication is disabled. YouTube may block requests if bot protection is triggered.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(8)
            }
        }
    }

    // MARK: - Engine Section

    private var engineSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Core Tools Status")
                    .font(.system(size: 13, weight: .semibold))

                VStack(spacing: 8) {
                    toolRow(name: "yt-dlp", status: tools.ytdlpVersion, isOk: tools.ytdlpVersion != "error" && tools.ytdlpVersion != "not found")
                    toolRow(name: "ffmpeg & ffprobe", status: tools.hasFFmpeg ? "Found (Bundled/System)" : "Missing", isOk: tools.hasFFmpeg)
                    toolRow(name: "Deno JS Engine", status: tools.hasDeno ? "Found (Bundled/System)" : "Missing", isOk: tools.hasDeno)
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Updates & Maintenance")
                    .font(.system(size: 13, weight: .semibold))

                Toggle("Automatically check for yt-dlp updates on launch", isOn: $autoUpdate)
                    .font(.system(size: 12))

                HStack(spacing: 10) {
                    Button("Check for Updates Now") {
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
        }
    }

    private func toolRow(name: String, status: String, isOk: Bool) -> some View {
        HStack {
            Circle()
                .fill(isOk ? Color.green : Color.orange)
                .frame(width: 8, height: 8)

            Text(name)
                .font(.system(size: 12, weight: .medium))

            Spacer()

            Text(status)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.accentGradient)
                    .frame(width: 64, height: 64)
                    .shadow(color: Theme.primaryAccent.opacity(0.35), radius: 8, y: 2)

                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 4) {
                Text("PlaylistGrab")
                    .font(.title2.bold())
                Text("High-Speed Native YouTube & Playlist Downloader")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("PlaylistGrab is free and open-source software (MIT License). It powers downloads using yt-dlp, Deno, and ffmpeg. Only download content you own or have permission to save.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)

            Divider()
                .padding(.horizontal, 40)

            Text("Protected by Apple Silicon Native Performance & Privacy.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}
