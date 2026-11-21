#!/usr/bin/env bash
# Builds PlaylistGrab.app (Apple Silicon) and a drag-to-install .dmg.
# Runs on a Mac. GitHub Actions runs it for you; see .github/workflows/build.yml.
set -euo pipefail

APP_NAME="PlaylistGrab"
VERSION="${VERSION:-0.0.0}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
BINDIR="$APP/Contents/Resources/bin"
LICDIR="$APP/Contents/Resources/licenses"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fetch() {  # fetch <url> <output file>
  curl -fL --retry 5 --retry-delay 5 --retry-all-errors -o "$2" "$1"
}

rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS" "$BINDIR" "$LICDIR"

echo "==> Building the Swift package (arm64)"
cd "$ROOT"
swift build -c release --arch arm64
BIN_PATH="$(swift build -c release --arch arm64 --show-bin-path)"
cp "$BIN_PATH/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"

echo "==> Writing Info.plist (version $VERSION)"
sed "s/__VERSION__/$VERSION/g" "$ROOT/Resources/Info.plist" > "$APP/Contents/Info.plist"

echo "==> Building the app icon"
ICONSET="$TMP/AppIcon.iconset"
mkdir -p "$ICONSET"
SRC="$ROOT/Resources/AppIcon.png"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$SRC" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$SRC" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

echo "==> Downloading yt-dlp"
fetch "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos" "$BINDIR/yt-dlp"
chmod +x "$BINDIR/yt-dlp"
fetch "https://github.com/yt-dlp/yt-dlp/releases/latest/download/THIRD_PARTY_LICENSES.txt" \
  "$LICDIR/yt-dlp-THIRD_PARTY_LICENSES.txt" || echo "   (yt-dlp third-party license file not available, skipping)"

echo "==> Downloading Deno"
fetch "https://github.com/denoland/deno/releases/latest/download/deno-aarch64-apple-darwin.zip" "$TMP/deno.zip"
unzip -o -q "$TMP/deno.zip" -d "$TMP/deno"
cp "$TMP/deno/deno" "$BINDIR/deno"
chmod +x "$BINDIR/deno"
fetch "https://raw.githubusercontent.com/denoland/deno/main/LICENSE.md" "$LICDIR/Deno-LICENSE.md" \
  || echo "   (Deno license file not available, skipping)"

echo "==> Downloading ffmpeg and ffprobe (static, Apple Silicon)"
for tool in ffmpeg ffprobe; do
  primary="https://ffmpeg.martin-riedl.de/redirect/latest/macos/arm64/release/$tool.zip"
  fallback="https://www.osxexperts.net/${tool}80arm.zip"
  if ! fetch "$primary" "$TMP/$tool.zip"; then
    echo "   primary mirror failed for $tool, trying fallback"
    fetch "$fallback" "$TMP/$tool.zip"
  fi
  mkdir -p "$TMP/$tool"
  unzip -o -q "$TMP/$tool.zip" -d "$TMP/$tool"
  found="$(find "$TMP/$tool" -type f -name "$tool" | head -n 1)"
  if [ -z "$found" ]; then
    echo "ERROR: could not find $tool inside the downloaded archive" >&2
    exit 1
  fi
  cp "$found" "$BINDIR/$tool"
  chmod +x "$BINDIR/$tool"
done
fetch "https://www.gnu.org/licenses/gpl-3.0.txt" "$LICDIR/ffmpeg-GPL-3.0.txt" \
  || echo "   (GPL text not available, skipping)"

echo "==> Checking that every bundled tool runs"
"$BINDIR/yt-dlp" --version
"$BINDIR/deno" --version | head -n 1
"$BINDIR/ffmpeg" -version | head -n 1
"$BINDIR/ffprobe" -version | head -n 1

echo "==> Adding license files"
cp "$ROOT/LICENSE" "$LICDIR/PlaylistGrab-LICENSE.txt"
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$LICDIR/THIRD_PARTY_NOTICES.md"

echo "==> Ad-hoc signing (no Apple developer account needed)"
# ffmpeg/ffprobe builds may be unsigned, and Apple Silicon refuses to run unsigned code.
# yt-dlp and Deno are left untouched; re-signing a PyInstaller binary can corrupt it.
for tool in ffmpeg ffprobe; do
  if ! codesign --verify "$BINDIR/$tool" 2>/dev/null; then
    codesign --force --sign - "$BINDIR/$tool"
  fi
done
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --verbose=2 "$APP" || echo "   (verification warning ignored)"

echo "==> Creating the DMG"
STAGE="$TMP/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
DMG="$DIST/$APP_NAME-$VERSION-arm64.dmg"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG"

echo "==> Done: $DMG"
