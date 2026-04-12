import requests
import json
import os
import time
from bs4 import BeautifulSoup

URL_BASE = "https://mltdjjszycfmokwqsqxm.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
HEADERS = {
    "apikey": KEY,
    "Authorization": f"Bearer {KEY}"
}
USER_AGENT = "AlioloRescue/1.0 (vitaliinoga@aliolo.com)"

with open("MISSING_MEDIA_REPORT.json", "r") as f:
    report = json.load(f)

# --- 1. Load Data Sources ---
# Flags
try:
    with open("scraped_states.json", "r") as f:
        flags_map = {s['name'].lower(): s['flag_url'] for s in json.load(f)}
except: flags_map = {}

# Domesticated
try:
    with open("domesticated_data.json", "r") as f:
        domesticated_map = {s['name'].lower(): s['url'] for s in json.load(f)}
except: domesticated_map = {}

# Dogs (Parse HTML)
dogs_map = {}
if os.path.exists("dog_breeds_source.html"):
    with open("dog_breeds_source.html", "r") as f:
        soup = BeautifulSoup(f.read(), 'html.parser')
        rows = soup.find_all('tr')
        for row in rows:
            tds = row.find_all('td')
            if len(tds) >= 2:
                img = tds[0].find('img')
                a = tds[1].find('a')
                if img and a:
                    src = img.get('src')
                    if img.get('srcset'):
                        src = img.get('srcset').split(',')[-1].strip().split(' ')[0]
                    if src.startswith('//'): src = 'https:' + src
                    dogs_map[a.get_text(strip=True).lower()] = src

# Planets Map
planet_wiki = {
    "mercury": "Mercury (planet)", "venus": "Venus", "earth": "Earth", "mars": "Mars",
    "jupiter": "Jupiter", "saturn": "Saturn", "uranus": "Uranus", "neptune": "Neptune",
    "ceres": "Ceres (dwarf planet)", "pluto": "Pluto", "haumea": "Haumea",
    "makemake": "Makemake", "eris": "Eris (dwarf planet)"
}

def get_wikipedia_image(title):
    wiki_url = "https://en.wikipedia.org/w/api.php"
    params = {
        "action": "query", "prop": "pageimages", "titles": title,
        "piprop": "original", "format": "json"
    }
    try:
        r = requests.get(wiki_url, params=params, headers={"User-Agent": USER_AGENT}).json()
        pages = r.get("query", {}).get("pages", {})
        for pid in pages:
            if int(pid) >= 0:
                return pages[pid].get("original", {}).get("source")
    except: pass
    return None

def restore_item(bucket, path, source_url):
    print(f"  Restoring: {path}")
    try:
        resp = requests.get(source_url, headers={"User-Agent": USER_AGENT}, timeout=15)
        if resp.status_code == 200:
            content_type = resp.headers.get('Content-Type', 'image/jpeg')
            upload_url = f"{URL_BASE}/storage/v1/object/{bucket}/{path}"
            up_resp = requests.post(upload_url, headers={**HEADERS, "Content-Type": content_type}, data=resp.content)
            if up_resp.status_code in [200, 201]:
                print(f"    [SUCCESS] Restored {path}")
                return True
            else:
                print(f"    [FAILED] Upload failed: {up_resp.text}")
        else:
            print(f"    [FAILED] Download failed ({resp.status_code}): {source_url}")
    except Exception as e:
        print(f"    [ERROR] {e}")
    return False

print("--- STARTING RESTORATION ---")
restored_count = 0

for item in report['card_images']:
    ans = item['answer'].lower().strip()
    path = item['path']
    src = None
    
    if "flags of the world" in path.lower() and ans in flags_map:
        src = flags_map[ans]
    elif "dogs" in path.lower() and ans in dogs_map:
        src = dogs_map[ans]
    elif "domesticated animals" in path.lower() and ans in domesticated_map:
        src = domesticated_map[ans]
    elif "planets" in path.lower() and ans in planet_wiki:
        src = get_wikipedia_image(planet_wiki[ans])
    elif "world landmarks" in path.lower() or "musical instruments" in path.lower():
        src = get_wikipedia_image(item['answer'])
        
    if src:
        if restore_item("card_images", path, src):
            restored_count += 1
            time.sleep(0.2)

print(f"\nRestoration complete. Successfully restored {restored_count} images.")
