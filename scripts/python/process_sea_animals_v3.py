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

missing_animals = [
  {"name": "Blue Whale", "search": "Blue whale", "level": 1},
  {"name": "Blobfish", "search": "Blobfish", "level": 4},
  {"name": "Angelfish", "search": "Pterophyllum", "level": 11},
  {"name": "Seal", "search": "Pinniped", "level": 17},
  {"name": "Stargazer fish", "search": "Stargazer (fish)", "level": 20},
  {"name": "Humphead parrotfish", "search": "Green humphead parrotfish", "level": 20}
]

def get_wikipedia_info_v3(search_term):
    wiki_url = "https://en.wikipedia.org/w/api.php"
    
    # 1. Search for the best page title
    search_params = {
        "action": "query",
        "list": "search",
        "srsearch": search_term,
        "format": "json"
    }
    try:
        s_resp = requests.get(wiki_url, params=search_params, headers={"User-Agent": USER_AGENT}).json()
        search_results = s_resp.get("query", {}).get("search", [])
        if not search_results:
            return None, None
        title = search_results[0]['title']
        
        # 2. Get images and langlinks
        params = {
            "action": "query",
            "prop": "langlinks|images|pageimages",
            "titles": title,
            "lllimit": 500,
            "piprop": "original",
            "format": "json"
        }
        resp = requests.get(wiki_url, params=params, headers={"User-Agent": USER_AGENT}).json()
        pages = resp.get("query", {}).get("pages", {})
        translations = { 'en': title }
        image_url = None
        
        for page_id in pages:
            if int(page_id) < 0: continue
            page = pages[page_id]
            
            # Try original from pageimages first
            image_url = page.get("original", {}).get("source")
            
            # If not found, try searching the 'images' list for something relevant
            if not image_url:
                images = page.get("images", [])
                for img in images:
                    img_title = img.get("title", "")
                    if any(ext in img_title.lower() for ext in [".jpg", ".png", ".jpeg"]):
                        # Get URL for this image
                        img_info_params = {
                            "action": "query",
                            "prop": "imageinfo",
                            "titles": img_title,
                            "iiprop": "url",
                            "format": "json"
                        }
                        ii_resp = requests.get(wiki_url, params=img_info_params, headers={"User-Agent": USER_AGENT}).json()
                        ii_pages = ii_resp.get("query", {}).get("pages", {})
                        for ii_pid in ii_pages:
                            image_url = ii_pages[ii_pid].get("imageinfo", [{}])[0].get("url")
                            if image_url: break
                    if image_url: break

            # Translations
            langlinks = page.get("langlinks", [])
            for link in langlinks:
                lang = link.get("lang")
                val = link.get("*")
                if lang in langs:
                    translations[lang] = val
                elif lang == 'fil' and 'tl' in langs:
                    translations['tl'] = val
                elif lang == 'zh-hans' and 'zh' in langs:
                    translations['zh'] = val
        return translations, image_url
    except Exception as e:
        print(f"Error fetching Wikipedia info for {search_term}: {e}")
        return None, None

def process():
    cards_to_insert = []
    
    for animal in missing_animals:
        name = animal['name']
        level = animal['level']
        
        card_id = str(uuid.uuid4())
        
        print(f"Processing {name} (Level {level})...")
        
        translations, img_url = get_wikipedia_info_v3(animal['search'])
        if not img_url:
            print(f"No image found for {name} on Wikipedia.")
            continue
            
        for lang in langs:
            if lang not in translations:
                translations[lang] = name
        
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
                    print(f"Failed to upload {name}: {up_resp.text}")
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
                    "answer": name,
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
                print(f"Failed to download image for {name} from {img_url}: {img_resp.status_code}")
        except Exception as e:
            print(f"Error processing {name}: {e}")

    if cards_to_insert:
        ins_resp = requests.post(f"{url_base}/rest/v1/cards", headers={**headers, "Content-Type": "application/json", "Prefer": "return=minimal"}, json=cards_to_insert)
        print(f"Inserted {len(cards_to_insert)} cards: {ins_resp.status_code}")

if __name__ == "__main__":
    process()
