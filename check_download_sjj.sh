#!/usr/bin/env bash

# Enable strict mode
set -euo pipefail

# Function to fetch valid mnemonic sign language codes
fetch_valid_lang_codes() {
    curl -s "https://data.jw-api.org/mediator/v1/languages/E/all" \
        | jq -r ".languages | map(select(.isSignLanguage == true)) | map(.code)[]"
}

# Function to fetch tracks for a given language
fetch_tracks() {
    local lang=$1
    curl -s "https://b.jw-cdn.org/apis/pub-media/GETPUBMEDIALINKS?output=json&pub=sjj&fileformat=MP4&alllangs=0&langwritten=$lang" \
        | jq ".files.$lang.MP4[].track" | sort -n | uniq
}

# Function to get the download link for a specific language and track number
get_download_link() {
    local lang=$1
    local number=$2

    # Fetch the download link
    local link
    link=$(curl -s "https://b.jw-cdn.org/apis/pub-media/GETPUBMEDIALINKS?output=json&pub=sjj&fileformat=MP4&alllangs=0&langwritten=$lang&track=$number" \
        | grep -Eo "https:\/\/[a-zA-Z0-9./?=_%:-]*r720P\.mp4")

    # Check if the link is empty
    if [[ -z "$link" ]]; then
        return 1  # Indicate failure (no link found)
    else
        echo "$link"  # Return the found link
        return 0  # Indicate success
    fi
}

# Function to check if languages are valid
check_valid_langs() {
    local invalid_langs=()
    local valid_langs=()
    for lang in "$@"; do
        if echo "$valid_lang_codes" | grep -q "$lang"; then
            valid_langs+=("$lang")
        else
            invalid_langs+=("$lang")
        fi
    done

    if [ ${#invalid_langs[@]} -ne 0 ]; then
        echo "Warning: The following are not valid mnemonic sign language codes: ${invalid_langs[*]}" >&2
    fi

    echo "${valid_langs[@]}"  # Return only valid languages
}

# Fetch the list of valid mnemonic sign language codes
valid_lang_codes=$(fetch_valid_lang_codes)

# Display help if no arguments are provided
if [[ "$#" -eq 0 || "$1" == "--help" ]]; then
    echo "Usage 1: $0 <lang1> [<lang2> ...]"
    echo "       Fetch and display video tracks for the given languages."
    echo "Usage 2: $0 <number1> [<number2> ...] <lang1> [<lang2> ...] [path_to_save]"
    echo "       Download multiple tracks across multiple languages."
    exit 1
fi

# Determine if it's Usage 2 (multiple tracks and multiple languages)
if [[ "$#" -ge 3 && "$1" =~ ^[0-9]+$ ]]; then
    # Extract numbers and languages from the input
    numbers=()
    langs=()
    path="."

    # Separate numbers, languages, and optional path
    for arg in "$@"; do
        if [[ "$arg" =~ ^[0-9]+$ ]]; then
            numbers+=("$arg")
        elif [[ "$arg" =~ ^[A-Z]{2,3}$ ]]; then
            langs+=("$arg")
        else
            path="$arg"
        fi
    done

    # Validate the numbers
    for number in "${numbers[@]}"; do
        if [ "$number" -lt 0 ] || [ "$number" -gt 159 ]; then
            echo "Error: Track number '$number' must be between 0 and 159."
            exit 1
        fi
    done

    # Check for valid languages
    valid_langs=$(check_valid_langs "${langs[@]}")

    # Ensure there's at least one valid language
    if [ -z "$valid_langs" ]; then
        echo "Error: No valid languages provided. Cannot proceed with download."
        exit 1
    fi

    # Ensure the specified path is a directory
    if [ ! -d "$path" ]; then
        echo "Error: Specified path '$path' is not a valid directory."
        exit 1
    fi

    # Download each requested track for each valid language
    for lang in $valid_langs; do
        for number in "${numbers[@]}"; do
            if link=$(get_download_link "$lang" "$number"); then
                aria2c --file-allocation=falloc --human-readable=false -x16 -s16 -j5 --remote-time=true -c --conditional-get=true --allow-overwrite=true --download-result=hide "$link" --dir="$path"
                echo "Download completed: Track $number in $lang saved to $path"
            else
                echo "Warning: No valid download link found for track '$number' in '$lang'."
            fi
        done
    done

else
    # Usage 1: Fetch and display tracks for given languages
    declare -A tracks

    # Check for valid languages before fetching
    valid_langs=$(check_valid_langs "$@")

    # Ensure there's at least one valid language
    if [ -z "$valid_langs" ]; then
        echo "Error: No valid languages provided. Cannot display tracks."
        exit 1
    fi

    # Fetch track lists for each valid language
    for lang in $valid_langs; do
        echo "Fetching tracks for $lang..."
        tracks[$lang]=$(fetch_tracks "$lang")
    done

    # Create arrays for each language
    declare -A lang_arr
    for lang in $valid_langs; do
        for track in ${tracks[$lang]}; do
            lang_arr["$lang,$track"]="$track ($lang)"
        done
    done

    # Output table header
    header="|No.|"
    for lang in $valid_langs; do
        header+="$(printf "%-9s|" "$lang")"
    done
    header+="\n|---|"
    for lang in $valid_langs; do
        header+="---------|"
    done
    echo -e "$header"

    # Loop from 0 to 159 to display each track
    for i in {0..159}; do
        row="|$(printf "%3d|" "$i")"
        for lang in $valid_langs; do
            val="${lang_arr["$lang,$i"]:-}"
            [ -z "$val" ] && val="         "
            row+="$(printf "%9s|" "$val")"
        done
        echo -e "$row"
    done
fi
