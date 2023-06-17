import requests
from bs4 import BeautifulSoup
import sys
import webbrowser
import urllib.parse
import re

# check if URL is provided as an argument
if len(sys.argv) < 2:
    print('Usage: python script.py <URL>')
    sys.exit(1)

# get the URL from command-line arguments
url = sys.argv[1]

# send a HTTP request to the specified URL
r = requests.get(url)

# create a BeautifulSoup object and specify the parser
soup = BeautifulSoup(r.text, 'html.parser')

# find the article with the specified id
article = soup.find('article', id='article')

if article is not None:
    # find all 'em' tags within the article
    em_tags = article.find_all('em')
    
    # remove all 'em' tags but keep their contents
    for tag in em_tags:
        tag.unwrap()

    # find all hyperlink tags within the article
    links = article.find_all('a')
    
    # get their full text, including the text within any nested tags
    links_text = [a.get_text() for a in links if a.get_text() is not None and any(char.isdigit() for char in a.get_text()) and not any(excluded_phrase.lower() in a.get_text().lower() for excluded_phrase in ["chương trình", "mục lục", "bài hát", "th bài học số"])]
    
    # join all the link text into a single string separated by semicolons
    result = ';'.join(links_text)

    # remove semicolon before pure number text
    result = re.sub(r';\s+(\d+)', r' \1', result)

    # remove all line breaks
    result = result.replace('\n', '')

    # replace all double spaces with single spaces
    while '  ' in result:
        result = result.replace('  ', ' ')

    # print results
    print(result)

    # URL encode the result
    result = urllib.parse.quote(result)

    # format the JW search URL with the result
    search_url = f'https://wol.jw.org/vi/wol/l/r47/lp-vt?q={result}'

    # open the search URL in the default web browser
    webbrowser.open(search_url)
else:
    print("The specified article id was not found.")
