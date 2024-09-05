#!/bin/bash

# Function to display help
display_help() {
    echo "Usage: $0 [-d YYYY-MM-DD] [-t HH:MM] [-f folder|file1 file2 ...]"
    echo
    echo "Options:"
    echo "  -d    Set the date (format: YYYY-MM-DD)."
    echo "  -t    Set the time (format: HH:MM)."
    echo "  -f    Specify a folder or a list of files."
    echo
    echo "Examples:"
    echo "  $0 -d 2024-09-05 -f /path/to/folder"
    echo "  $0 -t 15:30 -f file1.txt file2.txt"
    echo "  $0 -d 2024-09-05 -t 15:30 -f /path/to/folder"
}

# Initialize variables
date=""
time=""
files=""

# Parse command-line arguments
while getopts "d:t:f:h" option; do
    case $option in
        d) date="$OPTARG" ;;
        t) time="$OPTARG" ;;
        f) files="$OPTARG" ;;
        h) display_help
           exit 0 ;;
        *) echo "Invalid option."
           display_help
           exit 1 ;;
    esac
done

# Ensure at least date (-d) or time (-t) is provided
if [ -z "$date" ] && [ -z "$time" ]; then
    echo "Error: You must specify at least a date (-d) or a time (-t)."
    display_help
    exit 1
fi

# Ensure files or folder are specified
if [ -z "$files" ]; then
    echo "Error: You must specify a folder or files with -f."
    display_help
    exit 1
fi

# Apply the touch command to each file or folder
for file in $files; do
    if [ -e "$file" ]; then
        echo "Changing date/time of $file"

        # Get the current timestamp of the file
        current_time=$(stat -f "%Sm" -t "%Y%m%d%H%M" "$file")

        # Extract the current date and time
        current_date=${current_time:0:8}
        current_time=${current_time:8:4}

        # Update the date or time only if provided
        if [ -n "$date" ]; then
            new_date=$(echo "$date" | sed 's/-//g')
        else
            new_date=$current_date
        fi

        if [ -n "$time" ]; then
            new_time=$(echo "$time" | sed 's/://g')
        else
            new_time=$current_time
        fi

        # Construct the new timestamp
        new_datetime="$new_date$new_time"

        # Apply the new date/time to the file or folder
        touch -t "$new_datetime" "$file"
        echo "Updated $file to $new_datetime"
    else
        echo "File or folder $file does not exist."
    fi
done
