#!/bin/bash

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