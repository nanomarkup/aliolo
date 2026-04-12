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

subject_id = "2450ccd1-b439-4ed1-8280-30de3f41e400"
owner_id = "f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac"

langs = ['ar', 'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'fi', 'fr', 'ga', 'hi', 'hr', 'hu', 'id', 'it', 'ja', 'ko', 'lt', 'lv', 'mt', 'nl', 'pl', 'pt', 'ro', 'sk', 'sl', 'sv', 'tl', 'tr', 'uk', 'vi', 'zh']

USER_AGENT = "AlioloBot/1.0 (https://aliolo.com; hello@aliolo.com)"

sea_animals = [
  {"name": "Blue Whale", "image_url": "https://www.earthreminder.com/wp-content/uploads/2023/08/blue-whale-marine-mammal.jpg"},
  {"name": "Dolphin", "image_url": "https://www.earthreminder.com/wp-content/uploads/2023/08/dolphin-sea-animal.jpg"},
  {"name": "Jellyfish", "image_url": "https://www.earthreminder.com/wp-content/uploads/2023/08/jellyfish-marine-species.jpg"},
  {"name": "Blobfish", "image_url": "https://upload.wikimedia.org/wikipedia/commons/f/fe/Psychrolutes_marcidus.jpg"},
  {"name": "Octopus", "image_url": "https://www.earthreminder.com/wp-content/uploads/2023/08/octopus-sea-creature.jpg"},
  {"name": "Crab", "image_url": "https://www.earthreminder.com/wp-content/uploads/2023/08/crab-sea-creature.jpg"},
  {"name": "Starfish", "image_url": "https://www.earthreminder.com/wp-content/uploads/2023/08/starfish-sea-species.jpg"},
  {"name": "Sea turtle", "image_url": "https://www.earthreminder.com/wp-content/uploads/2023/08/sea-turtle-marine-species.jpg"},
  {"name": "Lobsters", "image_url": "https://www.earthreminder.com/wp-content/uploads/2023/08/lobster-sea-creature.jpg"},
  {"name": "Seahorse", "image_url": "https://www.earthreminder.com/wp-content/uploads/2023/08/seahorse.jpg"},
  {"name": "Angelfish", "image_url": "https://www.earthreminder.com/wp-content/uploads/2023/08/angelfish-sea-animal.jpg"},
  {"name": "Clownfish", "image_url": "https://www.earthreminder.com/wp-content/uploads/2023/08/clownfish-sea-animal.jpg"},
  {"name": "Swordfish", "image_url": "https://www.earthreminder.com/wp-content/uploads/2023/08/swordfish.jpg"},
  {"name": "Walrus", "image_url": "https://www.earthreminder.com/wp-content/uploads/2023/08/walrus-sea-animal.jpg"},
  {"name": "Eel", "image_url": "https://www.earthreminder.com/wp-content/uploads/2023/08/eel-sea-creature.jpg"},
  {"name": "Squid", "image_url": "https://www.earthreminder.com/wp-content/uploads/2023/08/squid-marine-species.jpg"},
  {"name": "Seal", "image_url": "https://www.earthreminder.com/wp-content/uploads/2023/08/seal-sea-animal.jpg"},
  {"name": "Manatee", "image_url": "https://www.earthreminder.com/wp-content/uploads/2023/08/manatee-sea-animal.jpg"},
  {"name": "Barracuda", "image_url": "https://www.earthreminder.com/wp-content/uploads/2023/08/barracuda-sea-creature.jpg"},
  {"name": "Manta ray", "image_url": "https://www.earthreminder.com/wp-content/uploads/2023/08/manta-ray-sea-animal.jpg"},
  {"name": "Cuttlefish", "image_url": "https://www.earthreminder.com/wp-content/uploads/2023/08/cuttlefish.jpg"},
  {"name": "Stargazer fish", "image_url": "https://www.earthreminder.com/wp-content/uploads/2023/08/stargazer-fish.jpg"},
  {"name": "Humphead parrotfish", "image_url": "https://www.earthreminder.com/wp-content/uploads/2023/08/humphead-parrotfish.jpg"}
]

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
        for page_id in pages:
            if int(page_id) < 0: continue
            langlinks = pages[page_id].get("langlinks", [])
            for link in langlinks:
                lang = link.get("lang")
                val = link.get("*")
                if lang in langs:
                    translations[lang] = val
                elif lang == 'fil' and 'tl' in langs:
                    translations['tl'] = val
                elif lang == 'zh-hans' and 'zh' in langs:
                    translations['zh'] = val
        return translations
    except Exception as e:
        print(f"Error fetching translations for {title}: {e}")
        return { 'en': title }

def process():
    cards_to_insert = []
    
    for i, animal in enumerate(sea_animals):
        level = i + 1
        if level > 20: level = 20
        
        card_id = str(uuid.uuid4())
        img_url = animal['image_url']
        
        print(f"Processing {animal['name']} (Level {level})...")
        
        translations = get_wikipedia_translations(animal['name'])
        for lang in langs:
            if lang not in translations:
                translations[lang] = animal['name']
        
        try:
            img_resp = requests.get(img_url, timeout=10, headers={"User-Agent": USER_AGENT})
            if img_resp.status_code == 200:
                content_type = img_resp.headers.get('Content-Type', 'image/jpeg')
                ext = content_type.split('/')[-1]
                if ext == 'jpeg': ext = 'jpg'
                if ';' in ext: ext = ext.split(';')[0]
                
                storage_path = f"{owner_id}/Types of Sea Animals/{card_id}.{ext}"
                
                upload_url = f"{url_base}/storage/v1/object/card_images/{storage_path}"
                up_headers = headers.copy()
                up_headers['Content-Type'] = content_type
                
                up_resp = requests.post(upload_url, headers=up_headers, data=img_resp.content)
                if up_resp.status_code not in [200, 201]:
                    print(f"Failed to upload {animal['name']}: {up_resp.text}")
                    continue
                
                final_img_url = f"{url_base}/storage/v1/object/public/card_images/{storage_path}"
                
                loc_data = {}
                for lang in langs:
                    loc_data[lang] = {
                        "answer": translations[lang],
                        "prompt": "",
                        "audio_url": None
                    }
                
                loc_data["global"] = {
                    "answer": animal['name'],
                    "prompt": "",
                    "audio_url": None,
                    "video_url": "",
                    "image_urls": [final_img_url]
                }
                
                cards_to_insert.append({
                    "id": card_id,
                    "subject_id": subject_id,
                    "level": level,
                    "owner_id": owner_id,
                    "is_public": True,
                    "test_mode": "image_to_text",
                    "localized_data": loc_data
                })
            else:
                print(f"Failed to download image for {animal['name']} from {img_url}: {img_resp.status_code}")
        except Exception as e:
            print(f"Error processing {animal['name']}: {e}")

    if cards_to_insert:
        ins_resp = requests.post(f"{url_base}/rest/v1/cards", headers={**headers, "Content-Type": "application/json", "Prefer": "return=minimal"}, json=cards_to_insert)
        print(f"Inserted {len(cards_to_insert)} cards: {ins_resp.status_code}")
        if ins_resp.status_code >= 400:
            print(ins_resp.text)

if __name__ == "__main__":
    process()
