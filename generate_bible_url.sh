#!/bin/bash

# Input text from argument
input_text="$1"
WTLOCALE="${2:-VT}"  # Default to VT if not provided
PUB="${3:-nwt}"      # Default to nwt if not provided

# Path to JSON file
json_file="/path/to/bible_lookup.json"

# Run Python with heredoc and pass arguments
# LESSON: Run Python directly without capturing output to avoid shell quirks (e.g., zsh adding '%' on macOS).
python3 - "$input_text" "$WTLOCALE" "$PUB" <<EOF
import json
import re
import sys

# Get input and parameters
text = sys.argv[1].strip()
wtlocale = sys.argv[2]
pub = sys.argv[3]

# Load JSON file
with open("$json_file", "r", encoding="utf-8") as f:
    books = json.load(f)

# Single-chapter book IDs
single_chapter_books = {'57', '63', '64', '65'}  # Philemon, 2 John, 3 John, Jude

# Regex patterns
pattern_book = r'^(.+?)\s+(\d+):(\d+(?:-\d+)?)$'      # e.g., "Mat 1:1" or "Đa 10:2-5"
pattern_single_chapter = r'^(.+?)\s+(\d+(?:-\d+)?)$'  # e.g., "Giu-đe 8" or "3Gi 2-4"
pattern_chapter_verse = r'(\d+):(\d+(?:-\d+)?)$'      # e.g., "19:9" or "11:1-3"
pattern_verse = r'(\d+(?:-\d+)?)$'                    # e.g., "8-11" or "18"

def generate_url(book_id, chapter, verse_start, verse_end=None):
    padded_book_id = str(book_id).zfill(2)
    padded_chapter = str(chapter).zfill(3)
    padded_start = str(verse_start).zfill(3)
    if verse_end:
        padded_end = str(verse_end).zfill(3)
        return f"https://www.jw.org/finder?srcid=jwlshare&wtlocale={wtlocale}&prefer=lang&bible={padded_book_id}{padded_chapter}{padded_start}-{padded_book_id}{padded_chapter}{padded_end}&pub={pub}"
    return f"https://www.jw.org/finder?srcid=jwlshare&wtlocale={wtlocale}&prefer=lang&bible={padded_book_id}{padded_chapter}{padded_start}&pub={pub}"

def parse_verse_range(verse_str):
    if '-' in verse_str:
        start, end = map(int, verse_str.split('-'))
        return start, end
    return int(verse_str), None

def process_segment(segment, book_id, current_chapter, full_text, is_first_segment=False):
    sub_segments = [s.strip() for s in segment.split(',')]
    verse_groups = []
    
    for i, sub_seg in enumerate(sub_segments):
        # LESSON: Handle the first segment specially to avoid re-parsing the book name as a verse, which caused "Invalid format" errors.
        if is_first_segment and i == 0:
            match_book = re.match(pattern_book, sub_seg)
            match_single = re.match(pattern_single_chapter, sub_seg)
            if match_book:
                _, chapter, verse = match_book.groups()
                current_chapter = int(chapter)
                start, end = parse_verse_range(verse)
                verse_groups.append((start, end, sub_seg, current_chapter))
            elif match_single and book_id in single_chapter_books:
                _, verse = match_single.groups()
                current_chapter = 1  # Single-chapter books always use chapter 1
                start, end = parse_verse_range(verse)
                verse_groups.append((start, end, sub_seg, current_chapter))
            else:
                return f"Error: Invalid book format '{sub_seg}' in '{full_text}'", None
        else:
            match_cv = re.match(pattern_chapter_verse, sub_seg)
            match_v = re.match(pattern_verse, sub_seg)
            if match_cv:
                chapter, verse = match_cv.groups()
                current_chapter = int(chapter)
                start, end = parse_verse_range(verse)
                verse_groups.append((start, end, sub_seg, current_chapter))
            elif match_v:
                if current_chapter is None:
                    return f"Error: No chapter defined for verse '{sub_seg}' in '{full_text}'", None
                verse = match_v.group(1)
                start, end = parse_verse_range(verse)
                verse_groups.append((start, end, sub_seg, current_chapter))
            else:
                return f"Error: Invalid format '{sub_seg}' in '{full_text}'", None
    
    # Group consecutive verses
    results = []
    i = 0
    while i < len(verse_groups):
        start, end, text, chapter = verse_groups[i]
        j = i + 1
        while (j < len(verse_groups) and 
               verse_groups[j][3] == chapter and 
               verse_groups[j][0] <= (end or start) + 1):
            end = verse_groups[j][1] or verse_groups[j][0]
            text += f", {verse_groups[j][2]}"
            j += 1
        url = generate_url(book_id, chapter, start, end)
        results.append(f"[{text}]({url})")
        i = j
    
    return ", ".join(results), current_chapter

def process_citation(text):
    # Split by semicolons
    segments = [s.strip() for s in text.split(';')]
    book_id = None
    chapter = None
    results = []

    # Extract book from first segment
    # LESSON: Extract book_id once and reuse it across segments to maintain consistency and avoid redundant lookups.
    first_segment = segments[0].split(',')[0].strip()
    match_book = re.match(pattern_book, first_segment)
    match_single = re.match(pattern_single_chapter, first_segment)
    
    if match_book:
        book, ch, verse = match_book.groups()
        book = book.lower()
        for b_id, data in books.items():
            if book in [data['official'].lower(), data['abbreviation'].lower(), data['name'].lower()]:
                book_id = b_id
                break
        else:
            return f"Error: Book not found for '{book}' in '{text}'"
        chapter = int(ch) if book_id not in single_chapter_books else 1
    elif match_single:
        book, verse = match_single.groups()
        book = book.lower()
        for b_id, data in books.items():
            if book in [data['official'].lower(), data['abbreviation'].lower(), data['name'].lower()]:
                book_id = b_id
                break
        else:
            return f"Error: Book not found for '{book}' in '{text}'"
        if book_id in single_chapter_books:
            chapter = 1  # Single-chapter books use chapter 1
        else:
            return f"Error: '{book}' requires chapter number (e.g., '{book} 1:1') in '{text}'"
    else:
        return f"Error: Invalid book format '{first_segment}' in '{text}'"

    if book_id in single_chapter_books and match_book:
        return f"Error: '{book}' is a single-chapter book; no chapter number allowed in '{text}'"

    # Process each segment
    for i, segment in enumerate(segments):
        result, chapter = process_segment(segment, book_id, chapter, text, is_first_segment=(i == 0))
        if "Error" in result:
            return result
        results.append(result)
    
    return "; ".join(results)

# Execute
result = process_citation(text)
# LESSON: Use default print() with newline to avoid zsh on macOS adding '%' for partial lines; echo -n and print(end='') triggered this.
print(result)
EOF
