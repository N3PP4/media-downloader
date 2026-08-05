#!/bin/zsh
set -euo pipefail

repo_dir=${0:A:h:h}
requested_architecture=${1:-all}

case "$requested_architecture" in
    all) architectures=(arm64 x86_64) ;;
    arm64|x86_64) architectures=($requested_architecture) ;;
    *)
        echo "Use all, arm64, or x86_64." >&2
        exit 2
        ;;
esac

for architecture in $architectures; do
    echo "Testing Media Downloader for $architecture…"
    tools_dir="$repo_dir/.build/vendor-tools/$architecture"
    build_dir="$repo_dir/.build/$architecture-apple-macosx/debug"

    swift build --package-path "$repo_dir" --arch "$architecture" --product MediaDownloaderCoreTestsRunner
    swift build --package-path "$repo_dir" --arch "$architecture" --product MediaDownloaderAppIntegrationRunner
    swift build --package-path "$repo_dir" --arch "$architecture" --product MediaDownloaderUISnapshot

    "$build_dir/MediaDownloaderCoreTestsRunner"
    "$repo_dir/scripts/prepare-tools.sh" "$architecture" "$tools_dir"
    "$build_dir/MediaDownloaderAppIntegrationRunner" --check-quality-labels
    "$build_dir/MediaDownloaderAppIntegrationRunner" --check-conversion-arguments
    python3 "$repo_dir/scripts/smoke-test.py" \
        "$tools_dir/yt-dlp" \
        "$tools_dir/ffmpeg" \
        "$build_dir/MediaDownloaderAppIntegrationRunner"

    "$build_dir/MediaDownloaderUISnapshot" \
        "$repo_dir/.build/ui-download-$architecture.png"
    "$build_dir/MediaDownloaderUISnapshot" --settings \
        "$repo_dir/.build/ui-settings-ja-light-$architecture.png"
    "$build_dir/MediaDownloaderUISnapshot" --settings --dark --english \
        "$repo_dir/.build/ui-settings-en-dark-$architecture.png"
    "$build_dir/MediaDownloaderUISnapshot" --conversion --maximum-height=2160 \
        "$repo_dir/.build/ui-quality-4k-$architecture.png"
    "$build_dir/MediaDownloaderUISnapshot" --inspection-failure --dark \
        "$repo_dir/.build/ui-inspection-failure-$architecture.png"
done

echo "All tests passed."
