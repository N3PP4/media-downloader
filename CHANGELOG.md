# Changelog

All notable changes to Media Downloader are documented here.

## 1.2.1 - 2026-08-05

### Added

- Add separate Apple Silicon and Intel application and DMG builds.
- Add an Intel software HEVC fallback when VideoToolbox conversion is
  unavailable.
- Show the supported OS, current build architecture, and developer in About.
- Keep all quality choices available with a clear notice when URL inspection
  cannot determine the available formats.

### Changed

- Support macOS Monterey 12 or later.
- Label automatic maximum quality with the detected resolution, such as
  `最高画質（4K）` or `Best quality (4K)`.
- Remove the tagline below the application name.

## 1.2.0 - 2026-08-05

### Added

- Download and sequentially convert every item in high-resolution playlists.
- Show playlist item counts, combined progress, preflight confirmation, and
  success/failure summaries while continuing after individual failures.
- Add a default-on setting for playlist preflight confirmation.

### Changed

- Reorganize Settings into Display, Download Settings, Bundled Tools, and About.
- Clarify playlist behavior and that yt-dlp and FFmpeg are bundled with the app.
- Align every checkbox setting to the same leading edge.

## 1.1.1 - 2026-08-05

### Fixed

- Make `Maximum resolution (Auto)` download the source's true maximum
  resolution instead of silently limiting the QuickTime-compatible path to
  1080p.
- Show the source maximum and current selected resolution separately so the
  resulting resolution and conversion requirement are explicit.
- Include the resolution in video filenames so downloading a new quality does
  not get skipped because another quality already exists.

## 1.1.0 - 2026-08-05

### Added

- Inspect available formats after a URL is pasted and show the source's
  available 4K, 1440p, 1080p, and 720p choices.
- Automatically convert AV1/Opus high-resolution downloads to QuickTime-ready
  HEVC (`hvc1`) and AAC using VideoToolbox hardware encoding.
- Show an inline conversion-time notice and confirmation dialog for choices
  that require conversion.
- Show separate downloading and QuickTime conversion progress.

### Changed

- Keep 1080p and lower H.264/AAC downloads on the faster no-conversion path.

## 1.0.1 - 2026-08-05

### Fixed

- Prefer H.264 video and AAC audio so downloaded MP4 files play correctly in
  QuickTime Player.
- Remove misleading 4K and 1440p choices while QuickTime-compatible YouTube
  formats are generally limited to 1080p.
- Migrate previously saved 4K/1440p settings to the compatible best setting.

## 1.0.0 - 2026-08-05

### Added

- Native SwiftUI macOS application.
- Video downloads using the best available quality, with optional 4K, 1440p,
  1080p, and 720p limits.
- MP3 conversion with three quality levels.
- Clipboard URL detection and a dedicated paste action.
- Download progress, current title, cancellation, completion, and error states.
- Custom destination folders with persistent settings.
- Optional full-playlist downloads.
- Optional automatic Finder reveal after completion.
- Japanese and English interface languages.
- Bundled, checksum-verified yt-dlp and FFmpeg executables for Apple Silicon.
- Ad-hoc signed `.app` and compressed `.dmg` build pipeline.
- Offline video and MP3 integration tests plus UI snapshot rendering.

### Retained

- The v0.5 terminal script remains available at `bin/ytd`.

## 0.5.0 - 2026-07-31

- Added working best-quality video and MP3 download modes.
- Added clipboard URL detection.
- Set Downloads as the destination directory.
- Ignored user yt-dlp configuration for predictable behavior.
