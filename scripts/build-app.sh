#!/bin/zsh
set -euo pipefail

repo_dir=${0:A:h:h}
architecture=${1:-${ARCHITECTURE:-$(uname -m)}}
configuration=${CONFIGURATION:-release}
app_name="Media Downloader"
dist_dir="$repo_dir/dist"
app_dir="$dist_dir/apps/$architecture/$app_name.app"
contents_dir="$app_dir/Contents"
macos_dir="$contents_dir/MacOS"
resources_dir="$contents_dir/Resources"
tools_dir="$repo_dir/.build/vendor-tools/$architecture"

case "$architecture" in
    arm64|x86_64) ;;
    *)
        echo "Unsupported architecture: $architecture" >&2
        echo "Use arm64 for Apple Silicon or x86_64 for Intel." >&2
        exit 1
        ;;
esac

"$repo_dir/scripts/prepare-tools.sh" "$architecture" "$tools_dir"
"$repo_dir/scripts/generate-icon.sh" "$repo_dir/.build/AppIcon.icns"

echo "Building Media Downloader ($configuration, $architecture)…"
swift build \
    --package-path "$repo_dir" \
    --configuration "$configuration" \
    --arch "$architecture" \
    --product MediaDownloaderApp

executable="$repo_dir/.build/$architecture-apple-macosx/$configuration/MediaDownloaderApp"
if [[ ! -x "$executable" ]]; then
    echo "Built executable was not found at $executable" >&2
    exit 1
fi

mkdir -p "$macos_dir" "$resources_dir/bin" "$resources_dir/licenses"
cp "$executable" "$macos_dir/MediaDownloaderApp"
cp "$repo_dir/Resources/Info.plist" "$contents_dir/Info.plist"
cp "$repo_dir/.build/AppIcon.icns" "$resources_dir/AppIcon.icns"
cp "$tools_dir/yt-dlp" "$resources_dir/bin/yt-dlp"
cp "$tools_dir/ffmpeg" "$resources_dir/bin/ffmpeg"
cp "$tools_dir/imageio-ffmpeg-LICENSE.txt" "$resources_dir/licenses/imageio-ffmpeg.txt"
cp "$tools_dir/yt-dlp-LICENSE.txt" "$resources_dir/licenses/yt-dlp-LICENSE.txt"
cp "$tools_dir/yt-dlp-THIRD_PARTY_LICENSES.txt" "$resources_dir/licenses/yt-dlp-THIRD_PARTY_LICENSES.txt"
cp "$tools_dir/FFmpeg-COPYING.GPLv2.txt" "$resources_dir/licenses/FFmpeg-COPYING.GPLv2.txt"
cp "$tools_dir/VERSIONS.txt" "$resources_dir/licenses/TOOL_VERSIONS.txt"
cp "$repo_dir/LICENSE" "$resources_dir/licenses/Media-Downloader-MIT.txt"
cp "$repo_dir/THIRD_PARTY_NOTICES.md" "$resources_dir/THIRD_PARTY_NOTICES.md"
chmod 755 "$macos_dir/MediaDownloaderApp" "$resources_dir/bin/yt-dlp" "$resources_dir/bin/ffmpeg"

for binary in "$macos_dir/MediaDownloaderApp" "$resources_dir/bin/ffmpeg"; do
    actual_architectures=$(lipo -archs "$binary")
    if [[ "$actual_architectures" != "$architecture" ]]; then
        echo "Unexpected architectures in $binary: $actual_architectures" >&2
        exit 1
    fi
done
lipo "$resources_dir/bin/yt-dlp" -verify_arch "$architecture"

codesign --force --sign - --timestamp=none "$resources_dir/bin/yt-dlp"
codesign --force --sign - --timestamp=none "$resources_dir/bin/ffmpeg"
codesign --force --deep --sign - --timestamp=none "$app_dir"
codesign --verify --deep --strict --verbose=2 "$app_dir"

echo "Built $app_dir"
