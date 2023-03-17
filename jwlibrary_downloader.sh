#!/bin/bash

strings=(
    "lff ASL"
    "lff SLV"
    "th BVL"
    "od ASL"
    "igw ASL"
    "ds BVL"
    "pt14 ASL"
)

for i in "${strings[@]}"; do
    set -- $i
    mkdir -p /Volumes/SSK/JWLibrary/$1_$2
    cd /Volumes/SSK/JWLibrary/$1_$2
    aria2c --file-allocation=falloc --human-readable=true -x16 -s16 -j5 --remote-time=true -c --conditional-get=true --allow-overwrite=true --download-result=full -i <(curl -s "https://b.jw-cdn.org/apis/pub-media/GETPUBMEDIALINKS?output=json&pub=${1}&alllangs=0&langwritten=${2}" | jq | grep -Eo "https:\/\/[a-zA-Z0-9./?=_%:-]*r720P\.(mp4|m4v)")
done

mkdir -p /Volumes/SSK/JWLibrary/
cd /Volumes/SSK/JWLibrary/
aria2c --file-allocation=falloc --human-readable=true -x16 -s16 -j5 --remote-time=true -c --conditional-get=true --allow-overwrite=true --download-result=full -i <(curl -s "https://b.jw-cdn.org/apis/pub-media/GETPUBMEDIALINKS?output=json&pub=sjj&alllangs=0&langwritten=BVL" | jq | grep -Eo "https:\/\/[a-zA-Z0-9./?=_%:-]*r720P\.(mp4|m4v)")

nwts=(
    "ASL"
    "BVL"
    "SLV"
)

for nwt_lang in "${nwts[@]}"; do
    mkdir -p /Volumes/SSK/JWLibrary/nwt_${nwt_lang}
    cd /Volumes/SSK/JWLibrary/nwt_${nwt_lang}
    for n in {1..66}; do
        aria2c --file-allocation=falloc --human-readable=true -x16 -s16 -j5 --remote-time=true -c --conditional-get=true --allow-overwrite=true --download-result=full -i <(curl "https://b.jw-cdn.org/apis/pub-media/GETPUBMEDIALINKS?output=json&pub=nwt&fileformat=MP4%2CM4V&alllangs=0&langwritten=${nwt_lang}&txtCMSLang=ASL&booknum=${n}" | jq | grep -Eo 'https:\/\/[a-zA-Z0-9./?=_%:-]*(r720P\.mp4|r480P\.m4v)')
    done
done

# Set the directory to search for text files
directory=/Volumes/SSK/JWLibrary

# Use the find command to search for text files modified within the last 7 days and in the last 8-30 days
num_one_files=$(find "$directory" -not -path '*/\.*' -type f -mtime -1 \( -iname "*.mp4" -o -iname "*.m4v" -o -iname "*.3gp" \) | wc -l)
num_seven_files=$(find "$directory" -not -path '*/\.*' -type f -mtime +1 -mtime -7 \( -iname "*.mp4" -o -iname "*.m4v" -o -iname "*.3gp" \) | wc -l)
num_eighttothirty_files=$(find "$directory" -not -path '*/\.*' -type f -mtime +7 -mtime -31 \( -iname "*.mp4" -o -iname "*.m4v" -o -iname "*.3gp" \) | wc -l)

# Echo the number of files found
echo "Number of new video files yesterday: $num_one_files"
find "$directory" -not -path '*/\.*' -type f -mtime -1 \( -iname "*.mp4" -o -iname "*.m4v" -o -iname "*.3gp" \)

echo

echo "Number of new video files within the last 7 days: $num_seven_files"
find "$directory" -not -path '*/\.*' -type f -mtime +1 -mtime -7 \( -iname "*.mp4" -o -iname "*.m4v" -o -iname "*.3gp" \)

echo

echo "Number of new video files between 8 to 30 days: $num_eighttothirty_files"
find "$directory" -not -path '*/\.*' -type f -mtime +7 -mtime -31 \( -iname "*.mp4" -o -iname "*.m4v" -o -iname "*.3gp" \)