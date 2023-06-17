import requests
from bs4 import BeautifulSoup
import sys
import webbrowser
import urllib.parse
import re

# Define static values as constants.
EXCLUDED_PHRASES = ["chương trình", "mục lục", "bài hát", "th bài học số"]
SEARCH_URL = 'https://wol.jw.org/vi/wol/l/r47/lp-vt?q={}'

def main():
    # Check if a URL was provided as a command-line argument.
    if len(sys.argv) < 2:
        # If not, ask the user for a URL.
        print('No URL provided as argument, please enter the URL now:')
        url = input()  # Ask user for URL
    else:
        # If a URL was provided as an argument, use it.
        url = sys.argv[1]

    # Remove any backslashes from the URL (if present) to ensure it is correctly formatted.
    url = url.replace("\\", "")

    # Attempt to send a HTTP request to the specified URL.
    try:
        r = requests.get(url)
    except requests.exceptions.RequestException as err:
        # If there was an error with the request, print the error and exit the program.
        print ("Something went wrong with the request:",err)
        sys.exit(1)

    # Parse the content of the page using BeautifulSoup.
    soup = BeautifulSoup(r.text, 'html.parser')

    # Try to find the 'article' element with the specified ID.
    article = soup.find('article', id='article')

    if article is not None:
        # If the article was found, find all 'em' tags within it.
        em_tags = article.find_all('em')
        for tag in em_tags:
            # Unwrap each 'em' tag (i.e., remove the tag but keep its contents).
            tag.unwrap()

        # Find all hyperlink tags within the article.
        links = article.find_all('a')

        # Get the text of each hyperlink tag, but only if it contains a digit and does not contain any excluded phrases.
        links_text = [a.get_text() for a in links if a.get_text() is not None and 
                      any(char.isdigit() for char in a.get_text()) and 
                      not any(excluded_phrase.lower() in a.get_text().lower() for excluded_phrase in EXCLUDED_PHRASES)]

        # Join all the link texts together into a single string, separated by semicolons.
        result = ';'.join(links_text)
        
        # Clean up the result string by removing unnecessary spaces and semicolons.
        result = re.sub(r';\s+(\d+)', r' \1', result)  # Remove space after semicolon if followed by a number
        result = result.replace('\n', '')  # Remove line breaks
        while '  ' in result:  # Replace all double spaces with single spaces
            result = result.replace('  ', ' ')
        while ';;' in result:  # Replace all double semicolons with single semicolon
            result = result.replace(';;', ';')
        while '; ' in result:  # Replace all "; " with ";"
            result = result.replace('; ', ';')

        # Print results and open the JW search URL in the default web browser.
        print(result)
        result = urllib.parse.quote(result)
        search_url = SEARCH_URL.format(result)
        webbrowser.open(search_url)
    else:
        # If the article was not found, print a message.
        print("The specified article id was not found.")

# If this script is run as the main program (not imported as a module), execute the main function.
if __name__ == "__main__":
    main()
