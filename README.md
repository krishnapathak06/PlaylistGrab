# PlaylistGrab

A small, native Mac app for downloading videos, whole playlists, or just the audio.
Paste a link, tick the videos you want, and press Download.

- Single videos and full playlists, with the option to untick videos you don't want
- Video (best available quality) or audio-only MP3
- Optional subtitles as `.srt` files, with a language picker (uses creator-made
  subtitles when they exist, otherwise YouTube's auto-generated ones)
- Parallel downloads (3 by default, up to 10 in Settings), with cancel and retry
- Playlists are saved in their own folder, files named like `01 - Video Title.mp4`
- Light and dark mode, no account or sign-in, no tracking
- Everything is bundled: yt-dlp, ffmpeg and Deno. yt-dlp updates itself at launch,
  so downloads keep working when YouTube changes things

Requires an Apple Silicon Mac (M1 or later) running macOS 13 or newer.

## Install

1. Download the latest `PlaylistGrab-x.y.z-arm64.dmg` from the
   [Releases](../../releases) page.
2. Open it and drag **PlaylistGrab** into **Applications**.
3. The app is not signed with a paid Apple developer certificate, so macOS will block
   the first launch. To allow it:
   - Try to open the app once, then go to **System Settings → Privacy & Security**,
     scroll down and click **Open Anyway**; or
   - run this once in Terminal: `xattr -dr com.apple.quarantine /Applications/PlaylistGrab.app`

## Using it

1. Paste a video or playlist link and press **Fetch**.
2. Choose **Video** or **Audio (MP3)**. Tick **Subtitles** and pick a language if you want them.
3. Choose where to save (the default is your Downloads folder).
4. Untick any videos you don't want, then press **Download**. Progress shows under **Downloads**.

Settings (⌘,) has the parallel download limit, default folder, video format
(compatible MP4 up to 1080p, or highest-quality MKV), and engine updates.

Notes:
- Some auto-generated subtitles are machine translations and can be rough. If a
  video has no subtitles in your language, it still downloads normally.
- Age-restricted, private and members-only videos need a login, which this app
  doesn't support.

## Building it yourself

You don't need Xcode. GitHub builds the app for you:

- Push a version tag (for example `v1.0.0`) and the workflow in `.github/workflows/build.yml`
  builds the app on a Mac runner and attaches the `.dmg` to a new release; or
- open the **Actions** tab, choose **Build PlaylistGrab**, and press **Run workflow**.
  The DMG is available as a build artifact on that run.

On a Mac with the Swift toolchain you can also run `bash scripts/build_app.sh`.

For quick development runs (`swift run`), install the tools with Homebrew first:
`brew install yt-dlp ffmpeg deno`. The app falls back to those when it isn't running
from a built `.app`.

## Responsible use

Only download content you own, that is in the public domain or Creative Commons
licensed, or that you otherwise have permission to save. Downloading from YouTube may
go against its Terms of Service. You are responsible for how you use this software.

## License

PlaylistGrab is released under the [MIT License](LICENSE). Bundled third-party
programs and their licenses are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
