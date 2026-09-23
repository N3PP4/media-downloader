# Direct distribution for macOS

Media Downloader is designed for direct distribution from GitHub Releases or
a website. It does not require the Mac App Store.

## Current development package

Run:

```sh
./scripts/test.sh all
./scripts/build-app.sh arm64
./scripts/package-dmg.sh arm64
./scripts/build-app.sh x86_64
./scripts/package-dmg.sh x86_64
```

The outputs are:

```text
dist/Media-Downloader-1.2.2-Apple-Silicon.dmg
dist/Media-Downloader-1.2.2-Intel.dmg
```

Each DMG contains the application, an Applications shortcut, and a `Manuals`
folder with separate Japanese and English first-launch guides. Keep both PDFs
in every architecture-specific package while the trial build is not notarized.

The current package is ad-hoc signed. This verifies the integrity of the app
bundle during development, but it is not a Developer ID signature and is not
notarized. A copy downloaded on another Mac can therefore be blocked by
Gatekeeper until the user explicitly chooses to open it.

## Public release checklist

Before publishing the download on a website:

1. Enroll in the Apple Developer Program and create a Developer ID Application
   certificate.
2. Sign the two helper executables and then the outer app bundle with the
   Developer ID identity and Hardened Runtime enabled.
3. Build the DMG and sign the DMG.
4. Submit the DMG to Apple's notary service with `notarytool`.
5. Staple the notarization ticket with `stapler`.
6. Run `spctl`, `codesign`, `stapler validate`, and `hdiutil verify` on the
   final artifact.
7. Verify that both first-launch manuals are present in the mounted DMG.
8. Publish the DMG checksum, source code, license, and third-party notices.

## Supported Macs

Version 1.2.2 supports macOS Monterey 12 or later. The app and FFmpeg are built
separately for arm64 and x86_64. The pinned upstream yt-dlp macOS executable is
dual-architecture and is included unchanged because thinning its PyInstaller
executable would invalidate its embedded archive. On the download page, direct
users with an M-series Chip to the Apple Silicon package and users with an
Intel Processor to the Intel package.

## Third-party components

Release builds contain separate yt-dlp and FFmpeg executables. Read
`THIRD_PARTY_NOTICES.md` before publishing or changing their versions. In
particular, the current FFmpeg build enables GPL components, so its GPL source
and license information must continue to be offered alongside distribution.
