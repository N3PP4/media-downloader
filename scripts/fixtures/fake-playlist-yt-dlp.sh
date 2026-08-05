#!/bin/zsh
set -u

for argument in "$@"; do
    if [[ "$argument" == "--dump-single-json" ]]; then
        if [[ " $* " == *" --flat-playlist "* ]]; then
            print -r -- '{"_type":"playlist","title":"Integration Playlist","playlist_count":3,"entries":[{"id":"fake1"},{"id":"fake2"},{"id":"fake3"}]}'
        else
            print -r -- '{"duration":1.0,"formats":[{"format_note":"1080p","width":1920,"height":1080,"vcodec":"avc1.640028","acodec":"none"},{"format_note":"2160p","width":3840,"height":2160,"vcodec":"av01.0.13M.08","acodec":"none"},{"vcodec":"none","acodec":"mp4a.40.2"}]}'
        fi
        exit 0
    fi
done

destination=""
audio_mode=0
arguments=("$@")
for (( index = 1; index <= ${#arguments}; index++ )); do
    if [[ "${arguments[$index]}" == "-P" ]] && (( index < ${#arguments} )); then
        destination="${arguments[$((index + 1))]}"
        break
    fi
    if [[ "${arguments[$index]}" == "--audio-format" ]]; then
        audio_mode=1
    fi
done

if [[ -z "$destination" || -z "${MD_FAKE_MEDIA_SOURCE:-}" ]]; then
    print -u2 -- "ERROR: fake playlist test is missing its destination or source"
    exit 2
fi

mkdir -p "$destination"
exit_status=0
for item_index in 1 2 3; do
    title="Integration Item $item_index"
    print -r -- $'__MD_ITEM__'"$item_index"$'\t3\t1.0\t'"$title"
    print -r -- "__MD_TITLE__$title"

    if [[ "${MD_FAKE_PLAYLIST_DELAY:-0}" != "0" && "$item_index" == "1" ]]; then
        sleep "$MD_FAKE_PLAYLIST_DELAY"
    fi

    if [[ "${MD_FAKE_PLAYLIST_FAILURE:-0}" == "1" && "$item_index" == "2" ]]; then
        print -u2 -- "ERROR: simulated failure for item 2"
        exit_status=1
        continue
    fi

    if (( audio_mode )); then
        output="$destination/$title [fake$item_index].mp3"
        ffmpeg -hide_banner -loglevel error -y -i "$MD_FAKE_MEDIA_SOURCE" -vn -c:a libmp3lame "$output"
    else
        output="$destination/$title [fake$item_index] [3840x2160].mp4"
        if [[ "${MD_FAKE_CONVERSION_FAILURE:-0}" == "1" && "$item_index" == "2" ]]; then
            print -r -- "invalid media retained for conversion failure test" > "$output"
        else
            cp "$MD_FAKE_MEDIA_SOURCE" "$output"
        fi
    fi
    print -r -- "[download] 100.0% of 1.00MiB"
    print -r -- "__MD_FILE__$output"
done

exit "$exit_status"
