#!/bin/bash

# Prompt the user to enter the path of the input video file
read -p "Enter the path of the input video file: " VIDEO_FILE

# Generate the output file path and name based on the input video file
OUTPUT_FILE="$(dirname "$VIDEO_FILE")/$(basename "$VIDEO_FILE" .mp4).m3u8"

# Write the M3U8 header to the output file
echo "#EXTM3U" > "$OUTPUT_FILE"

# Run ffprobe and jq to extract the chapter information and write it to the output file
# ffprobe -v quiet -show_chapters -print_format json "$VIDEO_FILE" | jq -r '.chapters[] | "#EXTINF:" + ((.end_time | tonumber) - (.start_time | tonumber) | tostring) + ", " + .tags.title + "\n" + "'"$VIDEO_FILE"'" + "#t=" + (.start_time | tostring) + "," + (.end_time | tostring)' >> "$OUTPUT_FILE"
ffprobe -v quiet -show_chapters -print_format json "$VIDEO_FILE" | jq -r '.chapters[] | "#EXTINF:" + ((.end_time | tonumber) - (.start_time | tonumber) | tostring) + ", " + .tags.title + "\n" + "#EXTVLCOPT:start-time=" + (.start_time | tostring) + "\n" + "#EXTVLCOPT:stop-time=" + (.end_time | tostring) + "\n" + "'"$VIDEO_FILE"'"' >> "$OUTPUT_FILE"

# Wipe metadata title and overwrites VIDEO_FILE
ffmpeg -v quiet -y -i "$VIDEO_FILE" -map 0 -c copy -metadata title= -f mp4 "${VIDEO_FILE}.temp"
mv "${VIDEO_FILE}.temp" "$VIDEO_FILE"

# Display the path and name of the output file
echo "M3U8 file saved at: $OUTPUT_FILE"
read -p "Press any key to exit..."
