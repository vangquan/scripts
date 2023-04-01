#!/bin/bash

# Ask for song number
read -p "Write the song number you want to find: " num_input

# Make sure num has 3 digits
num=$(printf "%03d" "$num_input")

# Get all the current signlanguage mnemonic on JW.ORG
sjjs=$(curl -s 'https://data.jw-api.org/mediator/v1/languages/E/all' | jq -r '.languages | map(select(.isSignLanguage == true)) | map(.code) | .[]')

# Check each sign language for song num_input for download links
for sjj_lang in ${sjjs[@]}; do
    curl -s "https://data.jw-api.org/mediator/v1/categories/${sjj_lang}/VODSJJMeetings" | jq | grep -Eo "https:\/\/[a-zA-Z0-9./?=_%:-]*${num}_r720P\.mp4"
done
