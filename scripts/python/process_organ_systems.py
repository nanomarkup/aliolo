import requests
import json
import uuid
import os
import re
from bs4 import BeautifulSoup

url_base = "https://mltdjjszycfmokwqsqxm.supabase.co"
apikey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
headers = {
    "apikey": apikey,
    "Authorization": f"Bearer {apikey}"
}

subject_id = "de0b6e00-8c3d-4a56-997d-6345cb4ee316"
owner_id = "f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac"
langs = ['ar', 'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'fi', 'fr', 'ga', 'hi', 'hr', 'hu', 'id', 'it', 'ja', 'ko', 'lt', 'lv', 'mt', 'nl', 'pl', 'pt', 'ro', 'sk', 'sl', 'sv', 'tl', 'tr', 'uk', 'vi', 'zh']
USER_AGENT = "AlioloBot/1.0 (https://aliolo.com; hello@aliolo.com)"

def get_wikipedia_info(title):
    wiki_url = "https://en.wikipedia.org/w/api.php"
    # Get translations and main image
    params = {
        "action": "query",
        "prop": "langlinks|pageimages",
        "titles": title,
        "lllimit": 500,
        "piprop": "original",
        "format": "json"
    }
    try:
        resp = requests.get(wiki_url, params=params, headers={"User-Agent": USER_AGENT}).json()
        pages = resp.get("query", {}).get("pages", {})
        translations = { 'en': title }
        image_url = None
        for pid in pages:
            if int(pid) < 0: continue
            page = pages[pid]
            image_url = page.get("original", {}).get("source")
            links = page.get("langlinks", [])
            for link in links:
                lang = link.get("lang")
                val = link.get("*")
                if lang in langs: translations[lang] = val
                elif lang == 'fil' and 'tl' in langs: translations['tl'] = val
                elif lang == 'zh-hans' and 'zh' in langs: translations['zh'] = val
        return translations, image_url
    except:
        return { 'en': title }, None

def process():
    url = "https://en.wikipedia.org/wiki/Organ_system"
    resp = requests.get(url, headers={"User-Agent": USER_AGENT})
    soup = BeautifulSoup(resp.text, "html.parser")
    
    # The table is likely the one under "Human organ systems"
    table = soup.find("table", class_="wikitable")
    if not table:
        print("Table not found")
        return

    cards_to_insert = []
    rows = table.find_all("tr")[1:] # Skip header
    
    for row in rows:
        cols = row.find_all("td")
        if not cols: continue
        
        name_col = cols[0]
        link = name_col.find("a")
        if not link: continue
        
        system_name = link.get_text().strip()
        wiki_title = link.get("title")
        
        print(f"Processing {system_name}...")
        
        translations, img_url = get_wikipedia_info(wiki_title)
        
        # If no image found on main page, we could try harder, but let's see
        if not img_url:
            print(f"No image for {system_name}, trying search...")
            # Try searching specifically for image
            pass

        if not img_url:
            print(f"Skipping {system_name} - no image.")
            continue

        # Download and upload image
        card_id = str(uuid.uuid4())
        try:
            i_resp = requests.get(img_url, headers={"User-Agent": USER_AGENT}, timeout=10)
            if i_resp.status_code == 200:
                ext = "jpg"
                if ".png" in img_url.lower(): ext = "png"
                
                storage_path = f"{owner_id}/Human Organ Systems/{card_id}.{ext}"
                upload_url = f"{url_base}/storage/v1/object/card_images/{storage_path}"
                
                up_resp = requests.post(upload_url, headers={**headers, "Content-Type": i_resp.headers.get("Content-Type", "image/jpeg")}, data=i_resp.content)
                if up_resp.status_code in [200, 201]:
                    final_img_url = f"{url_base}/storage/v1/object/public/card_images/{storage_path}"
                    
                    loc_data = {}
                    for lang in langs:
                        loc_data[lang] = {"answer": translations.get(lang, system_name), "prompt": "", "audio_url": None}
                    loc_data["global"] = {"answer": system_name, "prompt": "", "audio_url": None, "video_url": "", "image_urls": [final_img_url]}
                    
                    cards_to_insert.append({
                        "id": card_id,
                        "subject_id": subject_id,
                        "level": 1,
                        "owner_id": owner_id,
                        "is_public": True,
                        "test_mode": "image_to_text",
                        "localized_data": loc_data
                    })
                    print(f"Added {system_name}")
                else:
                    print(f"Upload failed for {system_name}")
        except Exception as e:
            print(f"Error for {system_name}: {e}")

    if cards_to_insert:
        ins_resp = requests.post(f"{url_base}/rest/v1/cards", headers={**headers, "Content-Type": "application/json", "Prefer": "return=minimal"}, json=cards_to_insert)
        print(f"Inserted {len(cards_to_insert)} cards: {ins_resp.status_code}")

if __name__ == "__main__":
    process()
