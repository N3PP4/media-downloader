#!/bin/zsh
set -euo pipefail

repo_dir=${0:A:h:h}
iconset_dir="$repo_dir/.build/AppIcon.iconset"
output_icns=${1:-"$repo_dir/.build/AppIcon.icns"}

mkdir -p "$iconset_dir" "${output_icns:h}"

swift "$repo_dir/scripts/generate-icon.swift" "$iconset_dir"

iconutil --convert icns "$iconset_dir" --output "$output_icns"
echo "Generated $output_icns"
