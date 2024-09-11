#!/usr/bin/env bash

# Enable strict mode
set -euo pipefail

# Function to fetch tracks for a given language
fetch_tracks() {
    local lang=$1
    curl -s "https://b.jw-cdn.org/apis/pub-media/GETPUBMEDIALINKS?output=json&pub=sjj&fileformat=MP4&alllangs=0&langwritten=$lang" \
        | jq ".files.$lang.MP4[].track" | sort -n | uniq
}

# Trap to handle cleanup (e.g., temporary files) - currently no temp files, but added for future use
trap "rm -f /tmp/some_temp_file" EXIT

# Check if at least one language is provided, or display help
if [[ "$#" -eq 0 || "$1" == "--help" ]]; then
    echo "Usage: $0 <lang1> [<lang2> ...]"
    echo "Fetch and display video tracks for the given languages."
    exit 1
fi

# Arrays to hold track lists for each language
declare -A tracks

# Fetch track lists for each language passed as arguments
for lang in "$@"; do
    echo "Fetching tracks for $lang..."
    tracks[$lang]=$(fetch_tracks "$lang")
done

# Create arrays for each language
declare -A lang_arr
for lang in "$@"; do
    for track in ${tracks[$lang]}; do
        lang_arr["$lang,$track"]="$track ($lang)"
    done
done

# Output table header
header="|No.|"
for lang in "$@"; do
    header+="$(printf "%-9s|" "$lang")"
done
header+="\n|---|"
for lang in "$@"; do
    header+="---------|"
done
echo -e "$header"

# Loop from 0 to 159 to display each track
for i in {0..159}; do
    row="|$(printf "%3d|" "$i")"
    for lang in "$@"; do
        val="${lang_arr["$lang,$i"]:-}"
        [ -z "$val" ] && val="         "
        row+="$(printf "%9s|" "$val")"
    done
    echo -e "$row"
done
