#!/bin/zsh
set -euo pipefail

repo_dir=${0:A:h:h}
architecture=${1:-$(uname -m)}
output_dir=${2:-"$repo_dir/.build/vendor-tools/$architecture"}
download_dir="$repo_dir/.build/tool-downloads/$architecture"
extract_dir="$repo_dir/.build/tool-extract/$architecture"

yt_dlp_version="2026.08.19"
imageio_version="0.6.0"
yt_dlp_sha256="0f192b7ec147ab6288885d6351d9ab67367640029b4377576ef46dd79cf7b202"
yt_dlp_license_sha256="7e12e5df4bae12cb21581ba157ced20e1986a0508dd10d0e8a4ab9a4cf94e85c"
yt_dlp_third_party_sha256="472aefe951c7db35e1657c1d13fd337140511ed6f2b329205105ad441c5a02b7"
ffmpeg_gpl_sha256="8177f97513213526df2cf6184d8ff986c675afb514d4e68a404010521b880643"

case "$architecture" in
    arm64)
        wheel_platform="macosx_11_0_arm64"
        wheel_sha256="b1ae3173414b5fc5f538a726c4e48ea97edc0d2cdc11f103afee655c463fa742"
        ffmpeg_sha256="6d175a4743ca50256e89a8cdd731100f9cee33bd79aeea46894d209410dc6617"
        ffmpeg_pattern="ffmpeg-macos-aarch64-*"
        ;;
    x86_64)
        wheel_platform="macosx_10_9_x86_64"
        wheel_sha256="9d2baaf867088508d4a3458e61eeb30e945c4ad8016025545f66c4b5aaef0a61"
        ffmpeg_sha256="4a4a968b98859588e98500ae25973d80a5ca5eed0724222b9f76360dcb72a001"
        ffmpeg_pattern="ffmpeg-macos-x86_64-*"
        ;;
    *)
        echo "Unsupported architecture: $architecture" >&2
        echo "Use arm64 for Apple Silicon or x86_64 for Intel." >&2
        exit 1
        ;;
esac

mkdir -p "$output_dir" "$download_dir" "$extract_dir"

yt_dlp_download="$download_dir/yt-dlp-$yt_dlp_version"
if [[ ! -f "$yt_dlp_download" ]]; then
    echo "Downloading yt-dlp $yt_dlp_version…"
    curl --fail --location --show-error \
        "https://github.com/yt-dlp/yt-dlp/releases/download/$yt_dlp_version/yt-dlp_macos" \
        --output "$yt_dlp_download"
fi

actual_yt_dlp_sha=$(shasum -a 256 "$yt_dlp_download" | awk '{print $1}')
if [[ "$actual_yt_dlp_sha" != "$yt_dlp_sha256" ]]; then
    echo "yt-dlp checksum verification failed." >&2
    exit 1
fi

wheel_download="$download_dir/imageio_ffmpeg-$imageio_version.whl"
if [[ ! -f "$wheel_download" ]]; then
    echo "Downloading the FFmpeg $architecture package…"
    python3 -m pip download \
        --disable-pip-version-check \
        --no-deps \
        --only-binary=:all: \
        --platform "$wheel_platform" \
        --python-version 311 \
        --implementation py \
        --abi none \
        --dest "$download_dir" \
        "imageio-ffmpeg==$imageio_version"
    downloaded_wheel=$(find "$download_dir" -maxdepth 1 -name 'imageio_ffmpeg-*.whl' -print -quit)
    mv "$downloaded_wheel" "$wheel_download"
fi

actual_wheel_sha=$(shasum -a 256 "$wheel_download" | awk '{print $1}')
if [[ "$actual_wheel_sha" != "$wheel_sha256" ]]; then
    echo "imageio-ffmpeg checksum verification failed." >&2
    exit 1
fi

if [[ ! -d "$extract_dir/imageio_ffmpeg" ]]; then
    ditto -x -k "$wheel_download" "$extract_dir"
fi

ffmpeg_source=$(find "$extract_dir/imageio_ffmpeg/binaries" -type f -name "$ffmpeg_pattern" -print -quit)
if [[ -z "$ffmpeg_source" ]]; then
    echo "FFmpeg executable was not found in the downloaded package." >&2
    exit 1
fi

actual_ffmpeg_sha=$(shasum -a 256 "$ffmpeg_source" | awk '{print $1}')
if [[ "$actual_ffmpeg_sha" != "$ffmpeg_sha256" ]]; then
    echo "FFmpeg checksum verification failed." >&2
    exit 1
fi

cp "$yt_dlp_download" "$output_dir/yt-dlp"
cp "$ffmpeg_source" "$output_dir/ffmpeg"
chmod 755 "$output_dir/yt-dlp" "$output_dir/ffmpeg"
lipo "$output_dir/yt-dlp" -verify_arch "$architecture"
actual_ffmpeg_architecture=$(lipo -archs "$output_dir/ffmpeg")
if [[ "$actual_ffmpeg_architecture" != "$architecture" ]]; then
    echo "Unexpected architectures in $output_dir/ffmpeg: $actual_ffmpeg_architecture" >&2
    exit 1
fi

license_source=$(find "$extract_dir" -path '*imageio_ffmpeg-*.dist-info/LICENSE' -print -quit)
cp "$license_source" "$output_dir/imageio-ffmpeg-LICENSE.txt"

yt_dlp_license="$download_dir/yt-dlp-$yt_dlp_version-LICENSE.txt"
yt_dlp_third_party="$download_dir/yt-dlp-$yt_dlp_version-THIRD_PARTY_LICENSES.txt"
ffmpeg_gpl="$download_dir/FFmpeg-COPYING.GPLv2.txt"

if [[ ! -f "$yt_dlp_license" ]]; then
    curl --fail --location --silent --show-error \
        "https://raw.githubusercontent.com/yt-dlp/yt-dlp/$yt_dlp_version/LICENSE" \
        --output "$yt_dlp_license"
fi
if [[ ! -f "$yt_dlp_third_party" ]]; then
    curl --fail --location --silent --show-error \
        "https://raw.githubusercontent.com/yt-dlp/yt-dlp/$yt_dlp_version/THIRD_PARTY_LICENSES.txt" \
        --output "$yt_dlp_third_party"
fi
if [[ ! -f "$ffmpeg_gpl" ]]; then
    curl --fail --location --silent --show-error \
        "https://raw.githubusercontent.com/FFmpeg/FFmpeg/n7.1/COPYING.GPLv2" \
        --output "$ffmpeg_gpl"
fi

[[ $(shasum -a 256 "$yt_dlp_license" | awk '{print $1}') == "$yt_dlp_license_sha256" ]] \
    || { echo "yt-dlp license checksum verification failed." >&2; exit 1; }
[[ $(shasum -a 256 "$yt_dlp_third_party" | awk '{print $1}') == "$yt_dlp_third_party_sha256" ]] \
    || { echo "yt-dlp third-party license checksum verification failed." >&2; exit 1; }
[[ $(shasum -a 256 "$ffmpeg_gpl" | awk '{print $1}') == "$ffmpeg_gpl_sha256" ]] \
    || { echo "FFmpeg GPL license checksum verification failed." >&2; exit 1; }

cp "$yt_dlp_license" "$output_dir/yt-dlp-LICENSE.txt"
cp "$yt_dlp_third_party" "$output_dir/yt-dlp-THIRD_PARTY_LICENSES.txt"
cp "$ffmpeg_gpl" "$output_dir/FFmpeg-COPYING.GPLv2.txt"

{
    echo "yt-dlp $yt_dlp_version"
    echo "FFmpeg 7.1"
    echo "imageio-ffmpeg $imageio_version"
    echo "architecture $architecture"
} > "$output_dir/VERSIONS.txt"

echo "Prepared tools in $output_dir"
