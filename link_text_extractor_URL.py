import requests
from bs4 import BeautifulSoup
import sys
import webbrowser
import urllib.parse
import re

# Define static values as constants
EXCLUDE_PHRASES = ["chương trình", "mục lục", "bài hát", "th bài học số"]
SEARCH_URL = 'https://wol.jw.org/vi/wol/l/r47/lp-vt?q={}'

def get_parsed_html(url):
    """
    This function sends a GET request to the provided URL and returns a BeautifulSoup object.
    """
    try:
        r = requests.get(url)
        r.raise_for_status()  # If the request failed, it will raise an HTTPError exception
    except requests.exceptions.RequestException as e:
        print(f"Error occurred: {e}")
        sys.exit(1)

    return BeautifulSoup(r.text, 'html.parser')

def get_links_text(article):
    """
    This function receives a BeautifulSoup object and returns a list of link texts after removing 'em' tags and applying filters.
    """
    # find all 'em' tags within the article and unwrap them
    em_tags = article.find_all('em')
    for tag in em_tags:
        tag.unwrap()

    # find all hyperlink tags within the article, filter and store their full text
    links = article.find_all('a')
    links_text = [
        a.get_text() for a in links
        if a.get_text() is not None
        and any(char.isdigit() for char in a.get_text())
        and not any(excluded_phrase.lower() in a.get_text().lower() for excluded_phrase in EXCLUDE_PHRASES)
    ]
    return links_text

def main(url):
    """
    Main function where all the steps are orchestrated.
    """
    # Get parsed HTML from the URL
    soup = get_parsed_html(url)

    # Find the 'article' with the specified id
    article = soup.find('article', id='article')
    if article is None:
        print("The specified article id was not found.")
        return

    # Extract the link texts
    links_text = get_links_text(article)

    # Join link texts, format the string, and remove unnecessary characters
    result = ';'.join(links_text)
    result = re.sub(r';\s+(\d+)', r' \1', result)  # Remove semicolon before pure number text
    result = result.replace('\n', '')  # Remove all line breaks
    while '  ' in result:  # Replace all double spaces with single spaces
        result = result.replace('  ', ' ')

    # Print results and open the JW search URL in the default web browser
    print(result)
    result = urllib.parse.quote(result)
    search_url = SEARCH_URL.format(result)
    webbrowser.open(search_url)

# If this script is run as the main program (not imported as a module), execute the main function
if __name__ == "__main__":
    # Check if URL is provided as an argument
    if len(sys.argv) < 2:
        print('Usage: python script.py <URL>')
        sys.exit(1)
    main(sys.argv[1])
