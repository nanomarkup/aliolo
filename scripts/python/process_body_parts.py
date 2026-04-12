import requests
import json
import uuid
import os
import re
import time
from bs4 import BeautifulSoup

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
    url = "https://en.wikipedia.org/wiki/Outline_of_human_anatomy"
    resp = requests.get(url, headers={"User-Agent": USER_AGENT})
    soup = BeautifulSoup(resp.text, "html.parser")
    
    results = []
    
    # Parts are in a nested UL structure under "General anatomy" -> "Parts of human body"
    # Let's find the LI containing "Parts of human body"
    parts_li = None
    all_lis = soup.find_all("li")
    for li in all_lis:
        if "Parts of human body" in li.get_text():
            parts_li = li
            break
    
    if not parts_li:
        print("Could not find Parts of human body list")
        return

    # Within this LI, there's another UL with Head, Neck, Torso, etc.
    top_ul = parts_li.find("ul")
    if not top_ul:
        print("Could not find top level parts list")
        return
        
    for item_li in top_ul.find_all("li", recursive=False):
        top_link = item_li.find("a")
        if not top_link: continue
        
        section_name = top_link.get_text().strip()
        if section_name in ["Head", "Neck", "Torso", "Lower limb"]:
            # Add the section itself
            results.append({"name": section_name, "wiki": top_link.get("title")})
            
            # Look for sub-items in a nested UL
            sub_ul = item_li.find("ul")
            if sub_ul:
                for sub_li in sub_ul.find_all("li", recursive=True):
                    sub_link = sub_li.find("a")
                    if sub_link and sub_link.get("title"):
                        name = sub_link.get_text().strip()
                        wiki = sub_link.get("title")
                        if wiki not in [r['wiki'] for r in results]:
                            results.append({"name": name, "wiki": wiki})

    print(f"Found {len(results)} potential body parts.")
    
    cards_to_insert = []
    for i, part in enumerate(results):
        print(f"[{i+1}/{len(results)}] Processing {part['name']}...")
        translations, img_url = get_wikipedia_info(part['wiki'])
        
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
            loc_data[lang] = {"answer": translations.get(lang, part['name']), "prompt": "", "audio_url": None}
        loc_data["global"] = {
            "answer": part['name'], "prompt": "", "audio_url": None, "video_url": "", 
            "image_urls": [final_img_url] if final_img_url else []
        }
        
        cards_to_insert.append({
            "id": card_id,
            "subject_id": subject_id,
            "level": (i // 10) + 1,
            "owner_id": owner_id,
            "is_public": True,
            "test_mode": "image_to_text",
            "localized_data": loc_data
        })
        print(f"Prepared {part['name']}")
        
        if len(cards_to_insert) >= 20:
            requests.post(f"{url_base}/rest/v1/cards", headers={**headers, "Content-Type": "application/json", "Prefer": "return=minimal"}, json=cards_to_insert)
            cards_to_insert = []
        
        time.sleep(0.1)

    if cards_to_insert:
        requests.post(f"{url_base}/rest/v1/cards", headers={**headers, "Content-Type": "application/json", "Prefer": "return=minimal"}, json=cards_to_insert)

if __name__ == "__main__":
    process()
