#!/bin/zsh
set -euo pipefail

repo_dir=${0:A:h:h}
architecture=${1:?Usage: verify-release.sh arm64|x86_64 /path/to/package.dmg}
dmg_path=${2:?Usage: verify-release.sh arm64|x86_64 /path/to/package.dmg}
app_path="$repo_dir/dist/apps/$architecture/Media Downloader.app"

case "$architecture" in
    arm64|x86_64) ;;
    *)
        echo "Use arm64 or x86_64." >&2
        exit 2
        ;;
esac

[[ -d "$app_path" ]] || { echo "Missing app: $app_path" >&2; exit 1; }
[[ -f "$dmg_path" ]] || { echo "Missing DMG: $dmg_path" >&2; exit 1; }

for binary in \
    "$app_path/Contents/MacOS/MediaDownloaderApp" \
    "$app_path/Contents/Resources/bin/ffmpeg"; do
    actual_architectures=$(lipo -archs "$binary")
    [[ "$actual_architectures" == "$architecture" ]] || {
        echo "Unexpected architectures in $binary: $actual_architectures" >&2
        exit 1
    }
done
lipo "$app_path/Contents/Resources/bin/yt-dlp" -verify_arch "$architecture"

minimum_system=$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$app_path/Contents/Info.plist")
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist")
[[ "$minimum_system" == "12.0" ]] || { echo "Unexpected minimum OS: $minimum_system" >&2; exit 1; }
[[ "$version" == "1.2.2" ]] || { echo "Unexpected version: $version" >&2; exit 1; }

app_minos=$(xcrun vtool -show-build "$app_path/Contents/MacOS/MediaDownloaderApp" | awk '/minos/{print $2; exit}')
[[ "$app_minos" == "12.0" ]] || { echo "Unexpected executable minimum OS: $app_minos" >&2; exit 1; }

codesign --verify --deep --strict --verbose=2 "$app_path"
hdiutil verify "$dmg_path"

mount_point=$(mktemp -d /tmp/media-downloader-verify.XXXXXX)
cleanup_mount() {
    hdiutil detach "$mount_point" >/dev/null 2>&1 || true
    rmdir "$mount_point" >/dev/null 2>&1 || true
}
trap cleanup_mount EXIT
hdiutil attach -nobrowse -readonly -mountpoint "$mount_point" "$dmg_path" >/dev/null
mounted_app="$mount_point/Media Downloader.app"
[[ -d "$mounted_app" ]] || { echo "The DMG does not contain Media Downloader.app" >&2; exit 1; }
codesign --verify --deep --strict --verbose=2 "$mounted_app"

manuals_dir="$mount_point/Manuals"
manual_ja="$manuals_dir/Media-Downloader-はじめにお読みください-v1.2.2.pdf"
manual_en="$manuals_dir/Media-Downloader-Getting-Started-v1.2.2.pdf"
[[ -d "$manuals_dir" ]] || { echo "The DMG does not contain the Manuals folder" >&2; exit 1; }
for manual in "$manual_ja" "$manual_en"; do
    [[ -s "$manual" ]] || { echo "Missing or empty bundled manual: $manual" >&2; exit 1; }
    [[ "$(head -c 4 "$manual")" == "%PDF" ]] || { echo "Invalid bundled PDF: $manual" >&2; exit 1; }
done
cleanup_mount
trap - EXIT

shasum -a 256 "$dmg_path"

echo "Verified Media Downloader 1.2.2 ($architecture) with Japanese and English manuals"
