#!/bin/zsh
set -euo pipefail

repo_dir=${0:A:h:h}
architecture=${1:-${ARCHITECTURE:-$(uname -m)}}

case "$architecture" in
    arm64)
        release_label="Apple-Silicon"
        ;;
    x86_64)
        release_label="Intel"
        ;;
    *)
        echo "Unsupported architecture: $architecture" >&2
        echo "Use arm64 for Apple Silicon or x86_64 for Intel." >&2
        exit 1
        ;;
esac

app_path="$repo_dir/dist/apps/$architecture/Media Downloader.app"
dmg_path="$repo_dir/dist/Media-Downloader-1.2.2-$release_label.dmg"
manuals_source_dir="$repo_dir/Resources/Manuals"
manual_ja="Media-Downloader-はじめにお読みください-v1.2.2.pdf"
manual_en="Media-Downloader-Getting-Started-v1.2.2.pdf"

if [[ ! -d "$app_path" ]]; then
    "$repo_dir/scripts/build-app.sh" "$architecture"
fi

for manual in "$manual_ja" "$manual_en"; do
    [[ -f "$manuals_source_dir/$manual" ]] || {
        echo "Missing bundled manual: $manuals_source_dir/$manual" >&2
        exit 1
    }
done

staging_dir=$(mktemp -d /tmp/media-downloader-dmg.XXXXXX)
cp -R "$app_path" "$staging_dir/Media Downloader.app"
ln -s /Applications "$staging_dir/Applications"
mkdir "$staging_dir/Manuals"
cp "$manuals_source_dir/$manual_ja" "$staging_dir/Manuals/$manual_ja"
cp "$manuals_source_dir/$manual_en" "$staging_dir/Manuals/$manual_en"

hdiutil create \
    -volname "Media Downloader" \
    -srcfolder "$staging_dir" \
    -format UDZO \
    -ov \
    "$dmg_path"

echo "Created $dmg_path"
