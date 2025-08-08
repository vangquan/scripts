#!/bin/bash
# copy_speaker_files.sh
#
# Purpose: Copy files from an events folder to speaker-specific folders based on event prefixes and talk numbers.
#          Optionally copy extra files to all speaker folders with --add-extras.
#          Use --commit to perform actual copying; without it, preview files to be copied (dry run).
# Usage: ./copy_speaker_files.sh <speakers_folder_path> <events_folder_path> [--add-extras] [--commit]
# Build: 2025-08-08 14:39

# Configuration
LANGUAGE_SUFFIXES=("E" "VT" "KO" "J")                           # Acceptable languages for file patterns
FILE_EXTENSIONS=("doc" "docx" "jwpub" "epub" "pdf" "mp4" "m4v") # Acceptable file extensions
SEARCH_DEPTH=10                                                 # Maximum search depth for events folder
# EXTRA_FOLDERS: Array of folders containing extra files to copy with --add-extras.
# Use macOS Finder's "Copy as Pathname" (right-click, hold Option) to get paths in single quotes.
# Both single and double quotes are supported. Comment out paths with # for testing.
EXTRA_FOLDERS=(
  # Reminders for outline talks
  # 'path/to/folder/CO-90'
  # Circuit Assembly report
  # 'path/to/folder/S-318'
)

# Initialize flags
ADD_EXTRAS=0
COMMIT=0

# Parse command-line arguments
if [ "$#" -lt 2 ]; then
    echo "Error: Please provide speakers folder path and events folder path as arguments."
    echo "Usage: $0 <speakers_folder_path> <events_folder_path> [--add-extras] [--commit]"
    exit 1
fi

SPEAKERS_FOLDER="$1"
EVENTS_FOLDER="$2"
shift 2

while [ $# -gt 0 ]; do
    case "$1" in
        --add-extras)
            ADD_EXTRAS=1
            shift
            ;;
        --commit)
            COMMIT=1
            shift
            ;;
        *)
            echo "Error: Unknown argument '$1'"
            echo "Usage: $0 <speakers_folder_path> <events_folder_path> [--add-extras] [--commit]"
            exit 1
            ;;
    esac
done

# Validate speakers and events folder paths
if [ ! -d "$SPEAKERS_FOLDER" ]; then
    echo "Error: Speakers folder '$SPEAKERS_FOLDER' does not exist."
    exit 1
fi

if [ ! -d "$EVENTS_FOLDER" ]; then
    echo "Error: Events folder '$EVENTS_FOLDER' does not exist."
    exit 1
fi

# Validate extra folders if --add-extras is used
if [ $ADD_EXTRAS -eq 1 ]; then
    if [ ${#EXTRA_FOLDERS[@]} -eq 0 ]; then
        echo "Warning: EXTRA_FOLDERS is empty, skipping extra files."
        ADD_EXTRAS=0
    else
        for folder in "${EXTRA_FOLDERS[@]}"; do
            if [ ! -d "$folder" ]; then
                echo "Error: Extra folder '$folder' does not exist."
                exit 1
            fi
        done
    fi
fi

# Temporary file to store potential duplicate files
DUPLICATES_FILE=$(mktemp)

# Function to join array elements with a separator
join_array() {
    local IFS="$1"
    shift
    echo "$*"
}

# Convert FILE_EXTENSIONS array to a find-compatible pattern
EXT_PATTERN=$(join_array "|" "${FILE_EXTENSIONS[@]}")
EXT_PATTERN="\.(${EXT_PATTERN})$"

# Function to copy or preview extra files to a destination folder
copy_extra_files() {
    local dest_folder="$1"
    if [ ! -d "$dest_folder" ]; then
        echo "Error: Destination folder '$dest_folder' does not exist. Skipping extra files."
        return
    fi
    for extra_folder in "${EXTRA_FOLDERS[@]}"; do
        # Find all files in extra folder with matching extensions
        while IFS= read -r file; do
            if [ -f "$file" ]; then
                dest_file="$dest_folder/$(basename "$file")"
                if [ -f "$dest_file" ]; then
                    echo "$file:$dest_file" >> "$DUPLICATES_FILE"
                else
                    if [ $COMMIT -eq 1 ]; then
                        if ! cp "$file" "$dest_file"; then
                            echo "Error: Failed to copy extra file '$(basename "$file")' to '$dest_folder'"
                        else
                            echo "Copied extra file '$(basename "$file")' to '$dest_folder'"
                        fi
                    else
                        echo "Would copy extra file '$(basename "$file")' to '$dest_folder'"
                    fi
                fi
            fi
        done < <(find "$extra_folder" -type f | grep -E "$EXT_PATTERN")
    done
}

# Function to process each destination folder
process_folder() {
    local folder="$1"
    local folder_name=$(basename "$folder")

    # Extract event prefixes and talk numbers using dynamic parsing
    IFS='|' read -ra PARTS <<< "$folder_name"
    for part in "${PARTS[@]}"; do
        # Trim whitespace
        part=$(echo "$part" | xargs)
        # Check if part matches event pattern (e.g., CA-brtk26_008, S-312-tk26_003)
        if [[ "$part" =~ ^([A-Za-z0-9-]+)_([0-9]{3})$ ]]; then
            event_prefix="${BASH_REMATCH[1]}" # e.g., CA-brtk26
            talk_number="${BASH_REMATCH[2]}"  # e.g., 008
            # Search for matching files in events folder
            for lang in "${LANGUAGE_SUFFIXES[@]}"; do
                # Construct file pattern (case-insensitive)
                file_pattern="${event_prefix}_${lang}_${talk_number}.*"
                # Find files recursively up to SEARCH_DEPTH
                while IFS= read -r file; do
                    if [ -f "$file" ]; then
                        # Check if destination folder exists
                        if [ -d "$folder" ]; then
                            dest_file="$folder/$(basename "$file")"
                            # Check for potential duplicate
                            if [ -f "$dest_file" ]; then
                                echo "$file:$dest_file" >> "$DUPLICATES_FILE"
                            else
                                if [ $COMMIT -eq 1 ]; then
                                    if ! cp "$file" "$dest_file"; then
                                        echo "Error: Failed to copy '$(basename "$file")' to '$folder'"
                                    else
                                        echo "Copied '$(basename "$file")' to '$folder'"
                                    fi
                                else
                                    echo "Would copy '$(basename "$file")' to '$folder'"
                                fi
                            fi
                        else
                            echo "Error: Destination folder '$folder' does not exist. Skipping files for $file_pattern."
                        fi
                    fi
                done < <(find "$EVENTS_FOLDER" -maxdepth "$SEARCH_DEPTH" -type f -iname "$file_pattern")
            done
        fi
    done

    # Copy or preview extra files if --add-extras is specified
    if [ $ADD_EXTRAS -eq 1 ]; then
        copy_extra_files "$folder"
    fi
}

# Find all child folders in speakers folder and process them
find "$SPEAKERS_FOLDER" -maxdepth 1 -type d ! -path "$SPEAKERS_FOLDER" -print0 | while IFS= read -r -d '' folder; do
    process_folder "$folder"
done

# Handle duplicate files
if [ -s "$DUPLICATES_FILE" ]; then
    echo -e "\nConflicts found:"
    while IFS=: read -r src dest; do
        echo "File '$(basename "$src")' already exists in '$(dirname "$dest")'"
    done < "$DUPLICATES_FILE"
    if [ $COMMIT -eq 1 ]; then
        echo -e "\nChoose an action for these conflicts:"
        echo "1. Overwrite existing files"
        echo "2. Skip duplicates"
        echo "3. Rename duplicates (add timestamp)"
        read -p "Enter choice (1, 2, or 3): " choice
        case "$choice" in
            1)
                echo "Overwriting conflicts..."
                while IFS=: read -r src dest; do
                    if ! cp -f "$src" "$dest"; then
                        echo "Error: Failed to overwrite '$(basename "$src")' in '$(dirname "$dest")'"
                    else
                        echo "Overwritten '$(basename "$dest")' in '$(dirname "$dest")'"
                    fi
                done < "$DUPLICATES_FILE"
                ;;
            2)
                echo "Skipping conflicts."
                ;;
            3)
                echo "Renaming conflicts with timestamp..."
                while IFS=: read -r src dest; do
                    timestamp=$(date +%Y%m%d%H%M%S)
                    base_name=$(basename "$dest")
                    dir_name=$(dirname "$dest")
                    extension="${base_name##*.}"
                    name_no_ext="${base_name%.*}"
                    new_dest="$dir_name/${name_no_ext}_${timestamp}.${extension}"
                    if ! cp "$src" "$new_dest"; then
                        echo "Error: Failed to copy '$(basename "$src")' to '$(basename "$new_dest")' in '$dir_name'"
                    else
                        echo "Copied '$(basename "$src")' as '$(basename "$new_dest")' in '$dir_name'"
                    fi
                done < "$DUPLICATES_FILE"
                ;;
            *)
                echo "Invalid choice. Skipping conflicts."
                ;;
        esac
    else
        echo -e "\nIn dry run mode, no action will be taken for conflicts."
    fi
fi

# Clean up temporary file
rm -f "$DUPLICATES_FILE"

if [ $COMMIT -eq 1 ]; then
    echo -e "\nScript execution completed."
else
    echo -e "\nDry run completed. Use --commit to copy files."
fi