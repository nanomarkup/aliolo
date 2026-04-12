import requests
import json
import uuid
import os

url_base = "https://mltdjjszycfmokwqsqxm.supabase.co"
apikey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
headers = {
    "apikey": apikey,
    "Authorization": f"Bearer {apikey}"
}

subject_id = "44202921-bedf-47c7-9ac1-5d47ba522f73"
owner_id = "f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac"
langs = ['ar', 'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'fi', 'fr', 'ga', 'hi', 'hr', 'hu', 'id', 'it', 'ja', 'ko', 'lt', 'lv', 'mt', 'nl', 'pl', 'pt', 'ro', 'sk', 'sl', 'sv', 'tl', 'tr', 'uk', 'vi', 'zh']
USER_AGENT = "AlioloBot/1.0 (https://aliolo.com; hello@aliolo.com)"

def get_wikipedia_info(title):
    wiki_url = "https://en.wikipedia.org/w/api.php"
    params = {
        "action": "query",
        "prop": "langlinks|pageimages",
        "titles": title,
        "piprop": "original",
        "format": "json"
    }
    try:
        resp = requests.get(wiki_url, params=params, headers={"User-Agent": USER_AGENT}).json()
        pages = resp.get("query", {}).get("pages", {})
        translations = { 'en': 'Leg' }
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
        return { 'en': 'Leg' }, None

def process():
    name = "Leg"
    wiki_title = "Human leg"
    print(f"Processing {name}...")
    
    translations, img_url = get_wikipedia_info(wiki_title)
    
    card_id = str(uuid.uuid4())
    final_img_url = ""
    
    if img_url:
        try:
            i_resp = requests.get(img_url, headers={"User-Agent": USER_AGENT}, timeout=10)
            if i_resp.status_code == 200:
                ext = "png" if "png" in img_url.lower() else "jpg"
                storage_path = f"{owner_id}/Body Parts/{card_id}.{ext}"
                upload_url = f"{url_base}/storage/v1/object/card_images/{storage_path}"
                up_resp = requests.post(upload_url, headers={**headers, "Content-Type": i_resp.headers.get("Content-Type", "image/jpeg")}, data=i_resp.content)
                if up_resp.status_code in [200, 201]:
                    final_img_url = f"{url_base}/storage/v1/object/public/card_images/{storage_path}"
        except:
            pass

    loc_data = {}
    for lang in langs:
        loc_data[lang] = {"answer": translations.get(lang, name), "prompt": "", "audio_url": None}
    loc_data["global"] = {
        "answer": name, "prompt": "", "audio_url": None, "video_url": "", 
        "image_urls": [final_img_url] if final_img_url else []
    }
    
    card = {
        "id": card_id,
        "subject_id": subject_id,
        "level": 1,
        "owner_id": owner_id,
        "is_public": True,
        "test_mode": "image_to_text",
        "localized_data": loc_data
    }
    
    resp = requests.post(f"{url_base}/rest/v1/cards", headers={**headers, "Content-Type": "application/json", "Prefer": "return=minimal"}, json=[card])
    print(f"Inserted Leg card: {resp.status_code}")

if __name__ == "__main__":
    process()
