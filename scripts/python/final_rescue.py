import requests
import json
import os
import time
from bs4 import BeautifulSoup
from gtts import gTTS
import io

URL_BASE = "https://mltdjjszycfmokwqsqxm.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
HEADERS = {
    "apikey": KEY,
    "Authorization": f"Bearer {KEY}"
}
USER_AGENT = "AlioloRescue/2.0 (vitaliinoga@aliolo.com)"

with open("MISSING_MEDIA_REPORT.json", "r") as f:
    report = json.load(f)

# --- Maps ---
try:
    with open("scraped_states.json", "r") as f:
        flags_map = {s['name'].lower(): s['flag_url'] for s in json.load(f)}
except: flags_map = {}

try:
    with open("domesticated_data.json", "r") as f:
        animals_map = {s['name'].lower(): s['url'] for s in json.load(f)}
except: animals_map = {}

planet_wiki = {
    "mercury": "Mercury (planet)", "venus": "Venus", "earth": "Earth", "mars": "Mars",
    "jupiter": "Jupiter", "saturn": "Saturn", "uranus": "Uranus", "neptune": "Neptune",
    "ceres": "Ceres (dwarf planet)", "pluto": "Pluto", "haumea": "Haumea",
    "makemake": "Makemake", "eris": "Eris (dwarf planet)"
}

def get_wikipedia_image(title):
    wiki_url = "https://en.wikipedia.org/w/api.php"
    params = {"action": "query", "prop": "pageimages", "titles": title, "piprop": "original", "format": "json"}
    try:
        r = requests.get(wiki_url, params=params, headers={"User-Agent": USER_AGENT}).json()
        pages = r.get("query", {}).get("pages", {})
        for pid in pages:
            if int(pid) >= 0: return pages[pid].get("original", {}).get("source")
    except: pass
    return None

def upload_file(bucket, path, data, content_type):
    upload_url = f"{URL_BASE}/storage/v1/object/{bucket}/{path}"
    # Use POST first, then PUT if already exists (though here they should be missing)
    res = requests.post(upload_url, headers={**HEADERS, "Content-Type": content_type}, data=data)
    if res.status_code in [200, 201]: return True
    if res.status_code == 409: # Conflict, already exists?
        res = requests.put(upload_url, headers={**HEADERS, "Content-Type": content_type}, data=data)
        return res.status_code == 200
    return False

print(f"--- STARTING FINAL RESTORATION ---")
print(f"Targeting {len(report['card_images'])} images and {len(report['card_audio'])} audio files.")

# --- 1. Restore Images ---
img_restored = 0
for item in report['card_images']:
    ans = item['answer'].lower().strip()
    path = item['path']
    src_url = None
    
    # Try to find source
    if "flags of the world" in path.lower() and ans in flags_map:
        src_url = flags_map[ans]
    elif "domesticated animals" in path.lower() and ans in animals_map:
        src_url = animals_map[ans]
    elif "planets" in path.lower() and ans in planet_wiki:
        src_url = get_wikipedia_image(planet_wiki[ans])
    elif any(subj in path.lower() for subj in ["world landmarks", "musical instruments", "human organ systems", "types of sea animals"]):
        src_url = get_wikipedia_image(item['answer'])
    
    if src_url:
        try:
            resp = requests.get(src_url, timeout=10, headers={"User-Agent": USER_AGENT})
            if resp.status_code == 200:
                ct = resp.headers.get('Content-Type', 'image/jpeg')
                if upload_file("card_images", path, resp.content, ct):
                    img_restored += 1
                    print(f"[IMG] Restored: {path}")
                    time.sleep(0.1)
        except: pass

# --- 2. Restore Audio ---
aud_restored = 0
for item in report['card_audio']:
    path = item['path']
    lang = item['lang']
    text = item['answer']
    
    if not text or not lang or lang == 'global': continue
    
    # Map Aliolo lang codes to gTTS codes
    gtts_lang = lang
    if lang == 'zh': gtts_lang = 'zh-CN'
    if lang == 'ga': gtts_lang = 'en' # gTTS doesn't support Irish (ga) well, use English fallback or skip
    
    try:
        tts = gTTS(text=text, lang=gtts_lang)
        fp = io.BytesIO()
        tts.write_to_fp(fp)
        fp.seek(0)
        
        if upload_file("card_audio", path, fp.read(), "audio/mpeg"):
            aud_restored += 1
            print(f"[AUD] Restored ({aud_restored}): {path}")
            time.sleep(0.1)
    except Exception as e:
        # print(f"[AUD] Failed {path}: {e}")
        pass

print(f"\n--- RESTORATION SUMMARY ---")
print(f"Images restored: {img_restored}")
print(f"Audio restored: {aud_restored}")
