#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 <wtlocale>"
    echo "Example: $0 VT  # Creates bible_lookup_VT.json"
    echo "Example: $0 E   # Creates bible_lookup_E.json"
    echo "Example: $0 SLV # Creates bible_lookup_KO.json"
    exit 1
}

# Check if wtlocale is provided
if [ $# -ne 1 ]; then
    usage
fi

WTLOCALE="$1"
OUTPUT_FILE="bible_lookup_${WTLOCALE}.json"
URL="https://wol.jw.org/wol/finder?pub=nwt&wtlocale=${WTLOCALE}"

# Temporary files
TEMP_PAGE="temp_page.html"
TEMP_IDS="temp_ids.txt"
TEMP_OFFICIAL="temp_official.txt"
TEMP_ABBR="temp_abbr.txt"
TEMP_NAMES="temp_names.txt"

# Clean up any existing temp files
rm -f "$TEMP_PAGE" "$TEMP_IDS" "$TEMP_OFFICIAL" "$TEMP_ABBR" "$TEMP_NAMES"

# Fetch the page once
echo "Fetching data for wtlocale ${WTLOCALE}..."
curl -sL "$URL" > "$TEMP_PAGE"

# Extract data from the single fetched page
echo "Processing data..."

# Book IDs
grep -Eo 'data-bookid="[0-9]+"' "$TEMP_PAGE" | \
    sed -E 's/data-bookid="([0-9]+)"/\1/' > "$TEMP_IDS"

# Official titles
grep -Eo '<span class="title ellipsized official">.*?</span>' "$TEMP_PAGE" | \
    sed -E 's/<\/?span[^>]*>//g' > "$TEMP_OFFICIAL"

# Abbreviations
grep -Eo '<span class="title ellipsized abbreviation">.*?</span>' "$TEMP_PAGE" | \
    sed -E 's/<\/?span[^>]*>//g' > "$TEMP_ABBR"

# Full names
grep -Eo '<span class="title ellipsized name">.*?</span>' "$TEMP_PAGE" | \
    sed -E 's/<\/?span[^>]*>//g' > "$TEMP_NAMES"

# Verify we got the same number of entries for each
count_ids=$(wc -l < "$TEMP_IDS")
count_official=$(wc -l < "$TEMP_OFFICIAL")
count_abbr=$(wc -l < "$TEMP_ABBR")
count_names=$(wc -l < "$TEMP_NAMES")

if [ "$count_ids" -ne "$count_official" ] || \
   [ "$count_ids" -ne "$count_abbr" ] || \
   [ "$count_ids" -ne "$count_names" ]; then
    echo "Error: Mismatched number of entries:"
    echo "IDs: $count_ids, Official: $count_official, Abbreviations: $count_abbr, Names: $count_names"
    rm -f "$TEMP_PAGE" "$TEMP_IDS" "$TEMP_OFFICIAL" "$TEMP_ABBR" "$TEMP_NAMES"
    exit 1
fi

# Generate JSON
echo "Generating $OUTPUT_FILE..."

{
    echo "{"
    paste "$TEMP_IDS" "$TEMP_OFFICIAL" "$TEMP_ABBR" "$TEMP_NAMES" | \
    while IFS=$'\t' read -r id official abbr name; do
        echo "  \"$id\": {"
        echo "    \"official\": \"$official\","
        echo "    \"abbreviation\": \"$abbr\","
        echo "    \"name\": \"$name\""
        echo "  },"
    done | sed '$s/,$//'
    echo "}"
} > "$OUTPUT_FILE"

# Clean up temporary files
rm -f "$TEMP_PAGE" "$TEMP_IDS" "$TEMP_OFFICIAL" "$TEMP_ABBR" "$TEMP_NAMES"

echo "Successfully created $OUTPUT_FILE"
