import requests
import json
import uuid
import os
import re

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

remaining_systems = [
    {"name": "Skeletal system", "wiki": "Skeletal system", "img_file": "Human_skeleton_front_en.svg"},
    {"name": "Muscular system", "wiki": "Muscular system", "img_file": "Muscles_anterior_labeled.png"},
    {"name": "Digestive system", "wiki": "Digestive system", "img_file": "Digestive_system_diagram_en.svg"}
]

def get_wikimedia_image_url(filename, width=1000):
    # Use Wikimedia thumbnail service for SVGs
    name = filename.replace(" ", "_")
    # MD5 hash of filename
    import hashlib
    m = hashlib.md5()
    m.update(name.encode('utf-8'))
    h = m.hexdigest()
    
    if filename.lower().endswith(".svg"):
        return f"https://upload.wikimedia.org/wikipedia/commons/thumb/{h[0]}/{h[0:2]}/{name}/{width}px-{name}.png"
    else:
        return f"https://upload.wikimedia.org/wikipedia/commons/{h[0]}/{h[0:2]}/{name}"

def get_wikipedia_translations(title):
    wiki_url = "https://en.wikipedia.org/w/api.php"
    params = {
        "action": "query",
        "prop": "langlinks",
        "titles": title,
        "lllimit": 500,
        "format": "json"
    }
    try:
        resp = requests.get(wiki_url, params=params, headers={"User-Agent": USER_AGENT}).json()
        pages = resp.get("query", {}).get("pages", {})
        translations = { 'en': title }
        for pid in pages:
            if int(pid) < 0: continue
            links = pages[pid].get("langlinks", [])
            for link in links:
                lang = link.get("lang")
                val = link.get("*")
                if lang in langs: translations[lang] = val
                elif lang == 'fil' and 'tl' in langs: translations['tl'] = val
                elif lang == 'zh-hans' and 'zh' in langs: translations['zh'] = val
        return translations
    except:
        return { 'en': title }

def process():
    # First, let's delete the trunacted "Digestive" card if it exists
    # We'll just add new ones.
    
    cards_to_insert = []
    for sys in remaining_systems:
        print(f"Processing {sys['name']}...")
        translations = get_wikipedia_translations(sys['wiki'])
        img_url = get_wikimedia_image_url(sys['img_file'])
        
        card_id = str(uuid.uuid4())
        try:
            i_resp = requests.get(img_url, headers={"User-Agent": USER_AGENT}, timeout=10)
            if i_resp.status_code == 200:
                ext = "png"
                storage_path = f"{owner_id}/Human Organ Systems/{card_id}.{ext}"
                upload_url = f"{url_base}/storage/v1/object/card_images/{storage_path}"
                
                up_resp = requests.post(upload_url, headers={**headers, "Content-Type": "image/png"}, data=i_resp.content)
                if up_resp.status_code in [200, 201]:
                    final_img_url = f"{url_base}/storage/v1/object/public/card_images/{storage_path}"
                    
                    loc_data = {}
                    for lang in langs:
                        loc_data[lang] = {"answer": translations.get(lang, sys['name']), "prompt": "", "audio_url": None}
                    loc_data["global"] = {"answer": sys['name'], "prompt": "", "audio_url": None, "video_url": "", "image_urls": [final_img_url]}
                    
                    cards_to_insert.append({
                        "id": card_id,
                        "subject_id": subject_id,
                        "level": 1,
                        "owner_id": owner_id,
                        "is_public": True,
                        "test_mode": "image_to_text",
                        "localized_data": loc_data
                    })
                    print(f"Added {sys['name']}")
                else:
                    print(f"Upload failed for {sys['name']}: {up_resp.text}")
            else:
                print(f"Download failed for {sys['name']} from {img_url}: {i_resp.status_code}")
        except Exception as e:
            print(f"Error for {sys['name']}: {e}")

    if cards_to_insert:
        ins_resp = requests.post(f"{url_base}/rest/v1/cards", headers={**headers, "Content-Type": "application/json", "Prefer": "return=minimal"}, json=cards_to_insert)
        print(f"Inserted {len(cards_to_insert)} cards: {ins_resp.status_code}")

if __name__ == "__main__":
    process()
