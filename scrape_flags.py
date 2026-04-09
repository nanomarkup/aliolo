import requests
from bs4 import BeautifulSoup
import json
import re

URL = "https://en.wikipedia.org/wiki/List_of_national_flags_of_sovereign_states"
HEADERS = {"User-Agent": "AlioloContentBot/1.0 (vitaliinoga@aliolo.com)"}

def scrape_flags():
    response = requests.get(URL, headers=HEADERS)
    if response.status_code != 200:
        print(f"Error {response.status_code}: {response.text[:200]}")
        return []
        
    soup = BeautifulSoup(response.content, 'html.parser')
    
    # We want the main table(s) that list sovereign states.
    # On this page, they are organized alphabetically with headers like "A", "B", etc.
    # Or sometimes it's one large table.
    
    states = []
    # Find all tables with class 'wikitable'
    tables = soup.find_all('table', {'class': 'wikitable'})
    
    for table in tables:
        # Check if table has a header row with "Flag" and "State"
        header_text = table.get_text().lower()
        if "flag" not in header_text or "state" not in header_text:
            continue
            
        rows = table.find_all('tr')
        for row in rows:
            cells = row.find_all(['td', 'th'])
            if len(cells) < 2:
                continue
            
            # Usually cell 0 is flag, cell 1 is state name
            img = cells[0].find('img')
            if not img:
                continue
                
            state_cell = cells[1]
            # Link to the state
            a = state_cell.find('a')
            if not a:
                continue
            
            state_name = a.get_text(strip=True)
            if not state_name or len(state_name) < 2:
                continue

            # Filter: If it's in a section called "Flags of de facto states", skip it.
            # But the user said "Use only sovereign states (usually the first main table). Do NOT include 'Flags of de facto states'".
            
            # The "Flags of de facto states" section is usually a separate table or at the end.
            # Let's check the parent header.
            h2 = table.find_previous('h2')
            if h2 and "de facto" in h2.get_text().lower():
                continue

            src = img.get('src')
            if img.get('srcset'):
                src = img.get('srcset').split(',')[-1].strip().split(' ')[0]
            
            if src.startswith('//'):
                src = 'https:' + src
            
            states.append({
                'name': state_name,
                'flag_url': src
            })
            
    return states

if __name__ == "__main__":
    states = scrape_flags()
    print(f"Scraped {len(states)} states.")
    # Deduplicate by name
    unique_states = {s['name']: s for s in states}.values()
    print(f"Unique states: {len(unique_states)}")
    with open('scraped_states.json', 'w') as f:
        json.dump(list(unique_states), f, indent=2)
