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

subject_id = "a6b5b079-4b75-400d-a9c6-43c28c80c040"
owner_id = "f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac"

langs = ['ar', 'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'fi', 'fr', 'ga', 'hi', 'hr', 'hu', 'id', 'it', 'ja', 'ko', 'lt', 'lv', 'mt', 'nl', 'pl', 'pt', 'ro', 'sk', 'sl', 'sv', 'tl', 'tr', 'uk', 'vi', 'zh']

USER_AGENT = "AlioloBot/1.0 (https://aliolo.com; hello@aliolo.com)"

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

def parse_domesticated_animals():
    with open("domesticated_animals_source.html", "r") as f:
        soup = BeautifulSoup(f, "html.parser")

    results = []
    table = soup.find("table", class_="wikitable")
    if table:
        rows = table.find_all("tr")
        for row in rows[1:]:
            cols = row.find_all("td")
            if len(cols) >= 6:
                link = cols[0].find("a")
                if link and link.get("title"):
                    wiki_title = link.get("title")
                else:
                    wiki_title = cols[0].get_text().strip().split("(")[0].strip()

                name = cols[0].get_text().strip()
                name = re.sub(r'\[\d+\]', '', name)
                name = name.split("(")[0].strip()
                
                img_tag = cols[5].find("img")
                img_url = None
                if img_tag:
                    img_url = img_tag.get("src")
                    if img_url:
                        if img_url.startswith("//"): img_url = "https:" + img_url
                        if "/thumb/" in img_url:
                            parts = img_url.split("/")
                            img_url = "/".join(parts[:-1]).replace("/thumb/", "/")
                
                if name and img_url:
                    results.append({"name": name, "wiki_title": wiki_title, "url": img_url})
                    if len(results) >= 41:
                        break
    return results

def process():
    animals = parse_domesticated_animals()
    print(f"Found {len(animals)} animals")
    
    cards_to_insert = []
    
    for i, animal in enumerate(animals):
        level = (i // 2) + 1
        if level > 20: level = 20
        
        card_id = str(uuid.uuid4())
        img_url = animal['url']
        
        print(f"Processing {animal['name']} (Level {level})...")
        
        translations = get_wikipedia_translations(animal['wiki_title'])
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
                
                storage_path = f"{owner_id}/Domesticated Animals/{card_id}.{ext}"
                
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
                print(f"Failed to download image for {animal['name']}: {img_resp.status_code}")
        except Exception as e:
            print(f"Error processing {animal['name']}: {e}")

    if cards_to_insert:
        ins_resp = requests.post(f"{url_base}/rest/v1/cards", headers={**headers, "Content-Type": "application/json", "Prefer": "return=minimal"}, json=cards_to_insert)
        print(f"Inserted {len(cards_to_insert)} cards: {ins_resp.status_code}")
        if ins_resp.status_code >= 400:
            print(ins_resp.text)

if __name__ == "__main__":
    process()
