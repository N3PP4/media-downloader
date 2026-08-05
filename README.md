# Media Downloader

Media Downloader is a native macOS application for downloading video or
converting media to MP3 with yt-dlp and FFmpeg. It is the graphical successor
to the original `bin/ytd` terminal tool.

## Features

- Native SwiftUI interface; no Terminal or Homebrew required for users
- Clipboard URL detection
- Dynamic 4K/1440p/1080p/720p choices based on the pasted URL
- Resolution-labelled filenames so 4K and 1080p copies can coexist
- QuickTime-compatible H.264/AAC for fast downloads up to 1080p
- Automatic HEVC/AAC conversion when higher resolutions require it
- Clear conversion notice, confirmation, and separate conversion progress
- MP3 conversion with selectable quality
- Download progress, cancellation, completion, and readable errors
- Custom download directory
- Optional playlist support
- Sequential QuickTime conversion for full high-resolution playlists
- Per-playlist progress, partial-failure summaries, and preflight confirmation
- Optional reveal in Finder after completion
- Japanese and English interfaces
- Bundled yt-dlp and FFmpeg in release builds

## Install the trial release

Download version 1.2.1 from the
[GitHub Releases page](https://github.com/N3PP4/media-downloader/releases/tag/v1.2.1),
then choose the package that matches the Mac:

```text
dist/Media-Downloader-1.2.1-Apple-Silicon.dmg
dist/Media-Downloader-1.2.1-Intel.dmg
```

Open the DMG, then drag Media Downloader into Applications. Version 1.2.1
supports macOS Monterey 12 or later.

- Choose **Apple Silicon** when About This Mac shows a Chip such as M1, M2,
  M3, M4, or later.
- Choose **Intel** when About This Mac shows an Intel Processor.

This trial release is ad-hoc signed for testing, not notarized with an
Apple Developer ID. Gatekeeper can warn when this build is transferred to a
different Mac. Complete the Developer ID signing and notarization checklist in
[`docs/DISTRIBUTION.md`](docs/DISTRIBUTION.md) before publishing it broadly.

## Use

1. Copy a supported media URL, or paste it into the URL field.
2. Select Video or MP3 and choose the desired quality.
3. Choose a destination folder if needed.
4. Select Download.

Use only media you are authorized to download. Website terms and copyright
rules still apply.

## Develop

Requirements:

- Apple Silicon or Intel Mac
- macOS Monterey 12 or later
- Swift 5.9 or later and the macOS Command Line Tools
- Python 3 and internet access the first time bundled tools are prepared

Run all automated checks, including offline MP4 and MP3 downloads:

```sh
./scripts/test.sh all
```

Build the application and DMG:

```sh
./scripts/build-app.sh arm64
./scripts/package-dmg.sh arm64
./scripts/build-app.sh x86_64
./scripts/package-dmg.sh x86_64
```

The build downloads pinned tool versions, verifies SHA-256 checksums, builds
the Swift application in release mode, embeds an architecture-specific FFmpeg
and yt-dlp's upstream dual-architecture macOS executable, and applies an ad-hoc
signature.

## Terminal version

The v0.5 command-line interface is retained:

```sh
./bin/ytd
```

It uses `yt-dlp` and FFmpeg installed on the local machine and downloads to
`~/Downloads`.

## Project structure

```text
Sources/MediaDownloaderCore/       URL validation, command building, parsing
Sources/MediaDownloaderApp/        SwiftUI interface and process management
Sources/MediaDownloaderEntry/      macOS application entry point
Sources/MediaDownloaderCoreTestsRunner/  dependency-free core checks
Sources/MediaDownloaderUISnapshot/ UI snapshot renderer
scripts/                            tests, tool preparation, app/DMG packaging
bin/ytd                             original v0.5 terminal tool
```

## License

Media Downloader is available under the MIT License. Release builds include
separate third-party executables with their own licenses. See
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
