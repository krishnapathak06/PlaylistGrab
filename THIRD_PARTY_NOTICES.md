# Third-party software

PlaylistGrab's own code is MIT licensed (see `LICENSE`). The downloadable app also
bundles the following separate programs. PlaylistGrab starts them as independent
processes; it does not link against them.

## yt-dlp
- What: the program that talks to YouTube and downloads the media.
- Project: https://github.com/yt-dlp/yt-dlp
- License: The Unlicense (public domain dedication). The official standalone executable
  also contains Python and other libraries under their own licenses; the list is shipped
  in `yt-dlp-THIRD_PARTY_LICENSES.txt` next to this file when available.

## Deno
- What: JavaScript runtime that yt-dlp uses to solve YouTube's JavaScript challenges.
- Project: https://github.com/denoland/deno
- License: MIT (see `Deno-LICENSE.md`).

## FFmpeg (ffmpeg and ffprobe)
- What: merges video and audio streams, converts audio to MP3, converts subtitles.
- Project and source code: https://ffmpeg.org/ and https://git.ffmpeg.org/ffmpeg.git
- Binaries: static Apple Silicon builds downloaded at build time from
  https://ffmpeg.martin-riedl.de (fallback: https://www.osxexperts.net). These builds
  are compiled with GPL-licensed components, so the binaries are distributed under the
  GNU General Public License. A copy of the license is in `ffmpeg-GPL-3.0.txt`.
  Build scripts and corresponding source for the Martin Riedl builds are linked from
  the build page above. To use your own build, replace the files in
  `PlaylistGrab.app/Contents/Resources/bin/`.
- ffmpeg is run as a separate program, so PlaylistGrab's own code stays MIT licensed.
