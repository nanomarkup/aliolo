import requests
import json
import uuid
import os
import re
import time

url_base = "https://mltdjjszycfmokwqsqxm.supabase.co"
apikey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
headers = {
    "apikey": apikey,
    "Authorization": f"Bearer {apikey}"
}

subject_id = "25fff407-d9d1-4e29-a176-41ce01157c63"
owner_id = "f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac"
langs = ['ar', 'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'fi', 'fr', 'ga', 'hi', 'hr', 'hu', 'id', 'it', 'ja', 'ko', 'lt', 'lv', 'mt', 'nl', 'pl', 'pt', 'ro', 'sk', 'sl', 'sv', 'tl', 'tr', 'uk', 'vi', 'zh']
USER_AGENT = "AlioloBot/1.0 (https://aliolo.com; hello@aliolo.com)"

missing_bones = [
    {"name": "Cranial bones", "wiki": "Neurocranium"},
    {"name": "Facial bones", "wiki": "Facial skeleton"},
    {"name": "Middle ear", "wiki": "Middle ear"},
    {"name": "Manubrium", "wiki": "Manubrium"},
    {"name": "Gladiolus", "wiki": "Body of sternum"},
    {"name": "Ribs", "wiki": "Rib"},
    {"name": "Pubis", "wiki": "Pubic bone"},
    {"name": "Shoulder girdle", "wiki": "Shoulder girdle"},
    {"name": "Hand", "wiki": "Hand"},
    {"name": "Carpals", "wiki": "Carpal bones"},
    {"name": "Metacarpals", "wiki": "Metacarpal bones"},
    {"name": "Phalanges of the hand", "wiki": "Phalanges of the hand"},
    {"name": "Proximal phalanges of hand", "wiki": "Proximal phalanges"},
    {"name": "Intermediate phalanges of hand", "wiki": "Intermediate phalanges"},
    {"name": "Distal phalanges of hand", "wiki": "Distal phalanges"},
    {"name": "Foot", "wiki": "Foot"},
    {"name": "Tarsus", "wiki": "Tarsus (skeleton)"},
    {"name": "Medial cuneiform bone", "wiki": "Medial cuneiform bone"},
    {"name": "Intermediate cuneiform bone", "wiki": "Intermediate cuneiform bone"},
    {"name": "Lateral cuneiform bone", "wiki": "Lateral cuneiform bone"},
    {"name": "Metatarsals", "wiki": "Metatarsal bones"},
    {"name": "Phalanges of the foot", "wiki": "Phalanges of the foot"},
    {"name": "Proximal phalanges of foot", "wiki": "Proximal phalanges of the foot"},
    {"name": "Intermediate phalanges of foot", "wiki": "Intermediate phalanges of the foot"},
    {"name": "Distal phalanges of foot", "wiki": "Distal phalanges of the foot"}
]

def get_wikipedia_info(title):
    wiki_url = "https://en.wikipedia.org/w/api.php"
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
    cards_to_insert = []
    for bone in missing_bones:
        print(f"Processing {bone['name']}...")
        translations, img_url = get_wikipedia_info(bone['wiki'])
        
        card_id = str(uuid.uuid4())
        final_img_url = ""
        
        if img_url:
            try:
                i_resp = requests.get(img_url, headers={"User-Agent": USER_AGENT}, timeout=10)
                if i_resp.status_code == 200:
                    ext = "png" if "png" in img_url.lower() else "jpg"
                    storage_path = f"{owner_id}/Bones/{card_id}.{ext}"
                    upload_url = f"{url_base}/storage/v1/object/card_images/{storage_path}"
                    up_resp = requests.post(upload_url, headers={**headers, "Content-Type": i_resp.headers.get("Content-Type", "image/jpeg")}, data=i_resp.content)
                    if up_resp.status_code in [200, 201]:
                        final_img_url = f"{url_base}/storage/v1/object/public/card_images/{storage_path}"
            except:
                pass

        loc_data = {}
        for lang in langs:
            loc_data[lang] = {"answer": translations.get(lang, bone['name']), "prompt": "", "audio_url": None}
        loc_data["global"] = {
            "answer": bone['name'], "prompt": "", "audio_url": None, "video_url": "", 
            "image_urls": [final_img_url] if final_img_url else []
        }
        
        cards_to_insert.append({
            "id": card_id,
            "subject_id": subject_id,
            "level": 1,
            "owner_id": owner_id,
            "is_public": True,
            "test_mode": "image_to_text",
            "localized_data": loc_data
        })
        print(f"Prepared {bone['name']}")

    if cards_to_insert:
        ins_resp = requests.post(f"{url_base}/rest/v1/cards", headers={**headers, "Content-Type": "application/json", "Prefer": "return=minimal"}, json=cards_to_insert)
        print(f"Inserted {len(cards_to_insert)} cards: {ins_resp.status_code}")

if __name__ == "__main__":
    process()
