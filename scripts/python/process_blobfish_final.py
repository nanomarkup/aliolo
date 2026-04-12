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
        return translations
    except Exception as e:
        return { 'en': title }

def process():
    name = "Blobfish"
    img_url = "https://upload.wikimedia.org/wikipedia/commons/1/15/Psychrolutes_marcidus.jpg"
    card_id = str(uuid.uuid4())
    
    translations = get_wikipedia_translations(name)
    for lang in langs:
        if lang not in translations:
            translations[lang] = name
            
    try:
        img_resp = requests.get(img_url, timeout=10, headers={"User-Agent": USER_AGENT})
        if img_resp.status_code == 200:
            content_type = img_resp.headers.get('Content-Type', 'image/jpeg')
            ext = "jpg"
            storage_path = f"{owner_id}/Types of Sea Animals/{card_id}.{ext}"
            upload_url = f"{url_base}/storage/v1/object/card_images/{storage_path}"
            up_headers = headers.copy()
            up_headers['Content-Type'] = content_type
            
            up_resp = requests.post(upload_url, headers=up_headers, data=img_resp.content)
            if up_resp.status_code in [200, 201]:
                final_img_url = f"{url_base}/storage/v1/object/public/card_images/{storage_path}"
                loc_data = {}
                for lang in langs:
                    loc_data[lang] = {"answer": translations[lang], "prompt": "", "audio_url": None}
                loc_data["global"] = {"answer": name, "prompt": "", "audio_url": None, "video_url": "", "image_urls": [final_img_url]}
                
                payload = [{
                    "id": card_id, "subject_id": subject_id, "level": 4, "owner_id": owner_id,
                    "is_public": True, "test_mode": "image_to_text", "localized_data": loc_data
                }]
                ins_resp = requests.post(f"{url_base}/rest/v1/cards", headers={**headers, "Content-Type": "application/json", "Prefer": "return=minimal"}, json=payload)
                print(f"Inserted Blobfish: {ins_resp.status_code}")
            else:
                print(f"Upload failed: {up_resp.text}")
        else:
            print(f"Download failed: {img_resp.status_code}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    process()
