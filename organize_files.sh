#!/usr/bin/env bash
# organize_files.sh
#
# Purpose: Organizes files into folders based on speaker names, with suffixes from program and part number
# Usage: ./organize_files.sh /path/to/folder [--organize] [--dry-run] [--extensions=ext1,ext2,...]
# Build: 2025-08-08 10:44

set -euo pipefail

# Usage message
usage() {
  echo "Usage: $0 <folder> [--organize] [--dry-run] [--extensions=ext1,ext2,...]"
  echo "  --organize            Create folders and move files"
  echo "  --dry-run             Show what would be done without making changes"
  echo "  --extensions=ext1,... Process only files with specified extensions (e.g., pdf,docx). Default: all files"
  exit 1
}

# Check arguments
if [[ $# -lt 1 ]]; then
  usage
fi

dir="$1"
organize=false
dry_run=false
extensions=""
shift

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --organize) organize=true ;;
    --dry-run) dry_run=true ;;
    --extensions=*) extensions="${1#*=}" ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
  shift
done

# Validate directory
if [[ ! -d "$dir" ]]; then
  echo "Error: '$dir' is not a directory"
  exit 1
fi

# Validate extensions
if [[ -n "$extensions" ]]; then
  if [[ "$extensions" =~ [[:space:]] || "$extensions" == ","* || "$extensions" == *"," || "$extensions" == *",,"* ]]; then
    echo "Error: Invalid extensions format. Use comma-separated list (e.g., pdf,docx)"
    exit 1
  fi
fi

# Build find pattern for extensions
if [[ -n "$extensions" ]]; then
  IFS=',' read -r -a ext_array <<< "$extensions"
  find_patterns=()
  for ext in "${ext_array[@]}"; do
    find_patterns+=("-name" "*.${ext}")
    if [[ "${#find_patterns[@]}" -gt 1 ]]; then
      find_patterns+=("-o")
    fi
  done
else
  find_patterns=("-name" "*")
fi

# List of words/phrases to ignore (case-insensitive)
IGNORE_PATTERNS=(
  ".DS_Store"
  ".pdf"
  "chairman"
  "chủ tọa"
  "interpretation"
  "talk"
  "bài giảng"
  "phiên dịch"
  "prayer"
  "cầu nguyện"
  "watchtower"
  "tháp canh"
)

# Normalize IGNORE_PATTERNS to NFC
normalized_ignore_patterns=()
for pattern in "${IGNORE_PATTERNS[@]}"; do
  normalized_pattern=$(echo "$pattern" | iconv -f UTF-8-MAC -t UTF-8)
  normalized_ignore_patterns+=("$normalized_pattern")
done

# Build grep -vi pattern
ignore_regex=$(IFS='|'; echo "${normalized_ignore_patterns[*]}")

# Function to generate suffix based on program and part number
get_suffix() {
  local program="$1"
  local part_number="$2"
  # Validate part number (must be numeric and positive)
  if [[ ! "$part_number" =~ ^[0-9]+$ || "$part_number" -lt 1 ]]; then
    echo ""
    return
  fi
  case "$program" in
    "CA-BR") printf "CA-brtk26_%03d" "$part_number" ;;
    "SMP") printf "S-312-tk26_%03d" "$part_number" ;;
    "CA-CO") printf "CA-cotk26_%03d" "$part_number" ;;
    *) echo "" ;;
  esac
}

# Temp file to hold candidate names
tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

# Step 1: Extract candidate name-like tokens
find "$dir" -type f "${find_patterns[@]}" -print0 | tr '\0' '\n' |
  sed 's#.*/##' |                              # strip paths
  iconv -f UTF-8-MAC -t UTF-8 |                # Normalize to NFC
  sed 's/ - /\n/g' |                           # split " - " separated segments
  sed 's/^[[:space:]]*//;s/[[:space:]]*$//' |  # trim whitespace
  grep -v '^$' |                               # remove empty lines
  grep -viE "$ignore_regex" |                  # filter out unwanted terms
  sort | uniq -c | sort -nr |                  # Count and sort
  awk '$1 <= 6 { $1=""; sub(/^ /,""); print }' | sort -u > "$tmpfile"

# Step 2: Create folders with all matching suffixes
if [[ "$organize" == true ]]; then
  echo "Ensuring folders exist:"
  while IFS= read -r name; do
    # Normalize name for matching
    normalized_name=$(echo "$name" | iconv -f UTF-8-MAC -t UTF-8)
    folder_name="$name"
    
    # Collect all suffixes for this name
    suffixes=()
    mapfile -t files < <(find "$dir" -maxdepth 1 -type f "${find_patterns[@]}" -print0 | tr '\0' '\n')
    for file in "${files[@]}"; do
      normalized_file=$(echo "$file" | iconv -f UTF-8-MAC -t UTF-8)
      # Extract the primary name from the file (last segment before role or end)
      primary_name=$(echo "$normalized_file" | sed -E 's/.* - ([^-].*?( \([^\)]+\))?)( - .*\.pdf|$)/\1/')
      if [[ "$primary_name" == "$normalized_name" ]]; then
        # Extract the part number from the role segment (last number before .pdf or end)
        part_number=$(echo "$normalized_file" | sed -E 's/.*[[:space:]]([0-9]+)(\.pdf|$)/\1/' | grep -E '^[0-9]+$' || echo "")
        program=$(echo "$normalized_file" | sed -E 's/.*2025-2026 ([A-Z-]+)([[:space:]].*)?/\1/' || echo "")
        if [[ -n "$part_number" && -n "$program" ]]; then
          suffix=$(get_suffix "$program" "$part_number")
          if [[ -n "$suffix" ]]; then
            suffixes+=("$suffix")
          fi
        fi
      fi
    done

    # Sort and deduplicate suffixes, then append to folder name with spaces
    if [[ ${#suffixes[@]} -gt 0 ]]; then
      sorted_suffixes=$(printf '%s\n' "${suffixes[@]}" | sort -u | tr '\n' '|' | sed 's/|$/ /' | sed 's/|/ | /g')
      folder_name="$name | $sorted_suffixes"
    fi

    folder="$dir/$folder_name"
    if [[ "$dry_run" == true ]]; then
      echo "✓ Would create: $folder"
    else
      mkdir -p "$folder"
      echo "✓ Created: $folder"
    fi
  done < "$tmpfile"
fi

# Step 3: Organize files into corresponding folders
if [[ "$organize" == true ]]; then
  echo -e "\nOrganizing files into folders:"
  find "$dir" -mindepth 1 -maxdepth 1 -type d | while IFS= read -r child_folder; do
    child_folder_name=$(basename "$child_folder")
    files_moved=false

    find "$dir" -mindepth 1 -maxdepth 1 -type f "${find_patterns[@]}" | while IFS= read -r file; do
      # Normalize to NFC
      normalized_file=$(echo "$file" | iconv -f UTF-8-MAC -t UTF-8)
      # Extract base name for matching (without suffixes)
      normalized_folder_base=$(echo "$child_folder_name" | sed 's/ | .*//')
      # Extract the primary name from the file
      primary_name=$(echo "$normalized_file" | sed -E 's/.* - ([^-].*?( \([^\)]+\))?)( - .*\.pdf|$)/\1/')
      
      if [[ "$primary_name" == "$normalized_folder_base" ]]; then
        current_parent=$(basename "$(dirname "$file")")
        if [[ "$current_parent" == "$child_folder_name" ]]; then
          continue
        fi

        if [[ "$dry_run" == true ]]; then
          echo "  ✔ Would move: $(basename "$file") → $child_folder_name/"
        else
          echo "  ✔ Moving: $(basename "$file") → $child_folder_name/"
          mv "$file" "$child_folder/"
        fi
        files_moved=true
      fi
    done

    if [[ "$files_moved" == false ]]; then
      echo "  ⚠ No matching files found for: $child_folder_name"
    fi
  done
fi

# Default behavior: print names if not organizing
if [[ "$organize" == false ]]; then
  echo "Extracted names:"
  while IFS= read -r name; do
    # Normalize name for matching
    normalized_name=$(echo "$name" | iconv -f UTF-8-MAC -t UTF-8)
    folder_name="$name"
    
    # Collect all suffixes for this name
    suffixes=()
    mapfile -t files < <(find "$dir" -maxdepth 1 -type f "${find_patterns[@]}" -print0 | tr '\0' '\n')
    for file in "${files[@]}"; do
      normalized_file=$(echo "$file" | iconv -f UTF-8-MAC -t UTF-8)
      # Extract the primary name from the file
      primary_name=$(echo "$normalized_file" | sed -E 's/.* - ([^-].*?( \([^\)]+\))?)( - .*\.pdf|$)/\1/')
      if [[ "$primary_name" == "$normalized_name" ]]; then
        # Extract the part number from the role segment (last number before .pdf or end)
        part_number=$(echo "$normalized_file" | sed -E 's/.*[[:space:]]([0-9]+)(\.pdf|$)/\1/' | grep -E '^[0-9]+$' || echo "")
        program=$(echo "$normalized_file" | sed -E 's/.*2025-2026 ([A-Z-]+)([[:space:]].*)?/\1/' || echo "")
        if [[ -n "$part_number" && -n "$program" ]]; then
          suffix=$(get_suffix "$program" "$part_number")
          if [[ -n "$suffix" ]]; then
            suffixes+=("$suffix")
          fi
        fi
      fi
    done

    # Sort and deduplicate suffixes, then append to folder name with spaces
    if [[ ${#suffixes[@]} -gt 0 ]]; then
      sorted_suffixes=$(printf '%s\n' "${suffixes[@]}" | sort -u | tr '\n' '|' | sed 's/|$/ /' | sed 's/|/ | /g')
      folder_name="$name | $sorted_suffixes"
    fi
    echo "$folder_name"
  done < "$tmpfile"
fi