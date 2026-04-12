import requests
from bs4 import BeautifulSoup

URL = "https://en.wikipedia.org/wiki/List_of_national_flags_of_sovereign_states"

def debug_scrape():
    response = requests.get(URL)
    soup = BeautifulSoup(response.content, 'html.parser')
    
    tables = soup.find_all('table', {'class': 'wikitable'})
    print(f"Found {len(tables)} wikitables.")
    
    for i, table in enumerate(tables):
        print(f"Table {i} first row: {table.find('tr').get_text(strip=True)[:100]}")

if __name__ == "__main__":
    debug_scrape()
