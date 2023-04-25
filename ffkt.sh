#!/bin/bash

# Ask user to enter input video file path
read -p "Enter path of input video file: " VIDEO_INPUT

# Extract the directory path and file name without extension from the input file path
VIDEO_DIR=$(dirname "$VIDEO_INPUT")
VIDEO_NAME=$(basename "$VIDEO_INPUT" | cut -f 1 -d '.')

# Ask user to enter the name of the output video file
# read -p "Enter name of output video file: " VIDEO_NAME_OUT
# Construct the output file path by appending ".mp4" to the file name and adding it to the directory path
# VIDEO_OUTPUT="$VIDEO_DIR/$VIDEO_NAME_OUT.mp4"

# Auto name the output video file
VIDEO_OUTPUT="${VIDEO_INPUT%.mp4} - withVTtext.mp4"

# Ask user to enter the citation to be added to the video
read -p "Enter Bible citation to be added to the video: " TEXT

# Replace any colons in the text with colons preceded by a backslash
TEXT=${TEXT//:/\\:}

# Position of the text on the video (in pixels from the top-left corner)
X=93
Y=100

# Font settings
FONT="$HOME/Library/Fonts/SourceSans3-Bold.otf"
FONTSIZE=35
# Fallbak to FONTCOLOR="0xd9d9d9"
FONTCOLOR="white"

# Prompt user to choose whether or not to interpolate the video
read -p "Do you want to interpolate the video? (y/n) " interpolate

# If the user agrees to interpolate, add the interpolation filter to the FFmpeg command
if [ "$interpolate" == "y" ]; then
  FILTER=",minterpolate=fps=60:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1"
else
  FILTER=""
fi

# FFmpeg command to add text to the video, with or without interpolation depending on user choice
ffmpeg -i "$VIDEO_INPUT" -vf "drawtext=fontfile=$FONT:fontcolor=$FONTCOLOR:fontsize=$FONTSIZE:x=$X:y=$Y:text='$TEXT'$FILTER" -c:a copy "$VIDEO_OUTPUT"
