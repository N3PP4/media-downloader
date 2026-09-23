# Third-party notices

The Media Downloader application is MIT-licensed. Release builds also contain
the following separately distributed command-line programs in
`Contents/Resources/bin`.

## yt-dlp

- Project: <https://github.com/yt-dlp/yt-dlp>
- Bundled version: 2026.08.19
- License: The Unlicense, with bundled components under their respective ISC,
  MIT, and other licenses.
- Source and complete notices: <https://github.com/yt-dlp/yt-dlp/tree/2026.08.19>

The corresponding Unlicense text and the official
`THIRD_PARTY_LICENSES.txt` from this release are included in the app at
`Contents/Resources/licenses`. The executable is distributed without
modification other than application code signing.

## FFmpeg

- Project: <https://ffmpeg.org/>
- Bundled executables: FFmpeg 7.1 from imageio-ffmpeg 0.6.0 for macOS arm64
  and x86_64
- FFmpeg license for this build: GNU General Public License version 2 or later
- Build configuration: available from `ffmpeg -buildconf`; this build enables
  GPL components including libx264, libx265, and libmp3lame.
- FFmpeg source: <https://github.com/FFmpeg/FFmpeg/tree/n7.1>
- FFmpeg license information: <https://ffmpeg.org/legal.html>
- Binary distributor: <https://github.com/imageio/imageio-ffmpeg>

imageio-ffmpeg is distributed under the BSD 2-Clause License. Its license is
included in release builds at `Contents/Resources/licenses/imageio-ffmpeg.txt`.

These tools run as separate processes. They are not linked into the Media
Downloader executable.
