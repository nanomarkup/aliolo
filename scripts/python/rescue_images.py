import requests
import json
import os
import time
import sys
from bs4 import BeautifulSoup

URL_BASE = "https://mltdjjszycfmokwqsqxm.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
HEADERS = {"apikey": KEY, "Authorization": f"Bearer {KEY}"}
USER_AGENT = "AlioloRescue/2.0 (vitaliinoga@aliolo.com)"

with open("MISSING_MEDIA_REPORT.json", "r") as f:
    report = json.load(f)

# --- Pre-load Data Sources ---
try:
    with open("scraped_states.json", "r") as f:
        flags_map = {s['name'].lower(): s['flag_url'] for s in json.load(f)}
except: flags_map = {}

try:
    with open("domesticated_data.json", "r") as f:
        animals_map = {s['name'].lower(): s['url'] for s in json.load(f)}
except: animals_map = {}

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

def get_wikipedia_image(title):
    wiki_url = "https://en.wikipedia.org/w/api.php"
    params = {"action": "query", "prop": "pageimages", "titles": title, "piprop": "original", "format": "json"}
    try:
        r = requests.get(wiki_url, params=params, headers={"User-Agent": USER_AGENT}, timeout=5).json()
        pages = r.get("query", {}).get("pages", {})
        for pid in pages:
            if int(pid) >= 0: return pages[pid].get("original", {}).get("source")
    except: pass
    return None

def upload_file(bucket, path, data, content_type):
    upload_url = f"{URL_BASE}/storage/v1/object/{bucket}/{path}"
    res = requests.post(upload_url, headers={**HEADERS, "Content-Type": content_type}, data=data, timeout=15)
    if res.status_code in [200, 201]: return True
    if res.status_code == 400 and "Duplicate" in res.text: return True
    return False

if len(sys.argv) < 3:
    print("Usage: python3 rescue_images.py <start_index> <end_index>")
    sys.exit(1)

start = int(sys.argv[1])
end = int(sys.argv[2])

print(f"--- RESTORING IMAGES [{start}:{end}] ---", flush=True)
items = report['card_images'][start:end]
total = len(items)
success = 0

for i, item in enumerate(items):
    path = item['path']
    ans = item['answer']
    ans_lower = ans.lower().strip()
    
    print(f"[{i+1}/{total}] Processing {ans}...", flush=True)
    
    src = None
    if "flags of the world" in path.lower() and ans_lower in flags_map:
        src = flags_map[ans_lower]
    elif "dogs" in path.lower() and ans_lower in dogs_map:
        src = dogs_map[ans_lower]
    elif "domesticated animals" in path.lower() and ans_lower in animals_map:
        src = animals_map[ans_lower]
    
    if not src:
        src = get_wikipedia_image(ans)
        
    if src:
        try:
            resp = requests.get(src, timeout=15, headers={"User-Agent": USER_AGENT})
            if resp.status_code == 200:
                ct = resp.headers.get('Content-Type', 'image/jpeg')
                if upload_file("card_images", path, resp.content, ct):
                    success += 1
                    print(f"  OK: {path}", flush=True)
        except: pass
    time.sleep(0.1)

print(f"Batch Done! Restored {success}/{total} images.", flush=True)
