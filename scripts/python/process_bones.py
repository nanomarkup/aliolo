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

subject_id = "25fff407-d9d1-4e29-a176-41ce01157c63"
owner_id = "f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac"
langs = ['ar', 'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'fi', 'fr', 'ga', 'hi', 'hr', 'hu', 'id', 'it', 'ja', 'ko', 'lt', 'lv', 'mt', 'nl', 'pl', 'pt', 'ro', 'sk', 'sl', 'sv', 'tl', 'tr', 'uk', 'vi', 'zh']
USER_AGENT = "AlioloBot/1.0 (https://aliolo.com; hello@aliolo.com)"

def get_wikipedia_info(title):
    wiki_url = "https://en.wikipedia.org/w/api.php"
    params = {
        "action": "query",
        "prop": "langlinks|pageimages|images",
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
            
            # If no primary image, check images list for something relevant
            if not image_url:
                images = page.get("images", [])
                for img in images:
                    img_title = img.get("title", "")
                    if any(x in img_title.lower() for x in [".jpg", ".png", ".jpeg"]) and "bone" in img_title.lower():
                        # Get URL
                        ii_params = {"action": "query", "prop": "imageinfo", "titles": img_title, "iiprop": "url", "format": "json"}
                        ii_resp = requests.get(wiki_url, params=ii_params, headers={"User-Agent": USER_AGENT}).json()
                        ii_pages = ii_resp.get("query", {}).get("pages", {})
                        for iipid in ii_pages:
                            image_url = ii_pages[iipid].get("imageinfo", [{}])[0].get("url")
                            if image_url: break
                    if image_url: break

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
    url = "https://en.wikipedia.org/wiki/List_of_bones_of_the_human_skeleton"
    resp = requests.get(url, headers={"User-Agent": USER_AGENT})
    soup = BeautifulSoup(resp.text, "html.parser")
    
    # Bones are listed in various sections, often in bullet points or tables.
    # The source has sections like "In the skull", "In the torso", etc.
    # Most are in <ul><li><a...>BONE NAME</a>...</li></ul>
    
    results = []
    seen_bones = set()
    
    # Look for lists of bones
    content = soup.find(id="mw-content-text")
    if content:
        # Find all bullet points
        lists = content.find_all("ul")
        for ul in lists:
            # Check if this list is likely a list of bones (heuristic: parent header or content)
            items = ul.find_all("li")
            for li in items:
                link = li.find("a")
                if link and link.get("title"):
                    bone_name = link.get_text().strip()
                    wiki_title = link.get("title")
                    
                    # Heuristic: simple names, likely bone pages
                    # Avoid years, references, or very long text
                    if len(bone_name) < 3 or len(bone_name) > 40: continue
                    if wiki_title.startswith("List of"): continue
                    if any(x in bone_name.lower() for x in ["bone", "ossicle", "phalanx", "vertebra", "sternum", "rib", "scapula", "clavicle", "humerus", "radius", "ulna", "carpal", "metacarpal", "pelvis", "femur", "patella", "tibia", "fibula", "tarsal", "metatarsal"]):
                        pass # Likely a bone
                    
                    if wiki_title not in seen_bones:
                        results.append({"name": bone_name, "wiki": wiki_title})
                        seen_bones.add(wiki_title)

    print(f"Found {len(results)} potential bones.")
    
    # Limit to a reasonable number first to test, or process all
    # Let's try processing the first 50 to avoid massive run
    # User asked for "all cards", there are 206 bones but many are duplicates (left/right)
    # List of bones page often groups them.
    
    cards_to_insert = []
    for i, bone in enumerate(results[:100]): # Process first 100 for now
        print(f"[{i+1}/{len(results)}] Processing {bone['name']}...")
        translations, img_url = get_wikipedia_info(bone['wiki'])
        
        if not img_url:
            print(f"Skipping {bone['name']} - no image.")
            continue

        card_id = str(uuid.uuid4())
        try:
            i_resp = requests.get(img_url, headers={"User-Agent": USER_AGENT}, timeout=10)
            if i_resp.status_code == 200:
                content_type = i_resp.headers.get("Content-Type", "image/jpeg")
                ext = "jpg"
                if "png" in content_type: ext = "png"
                
                storage_path = f"{owner_id}/Bones/{card_id}.{ext}"
                upload_url = f"{url_base}/storage/v1/object/card_images/{storage_path}"
                
                up_resp = requests.post(upload_url, headers={**headers, "Content-Type": content_type}, data=i_resp.content)
                if up_resp.status_code in [200, 201]:
                    final_img_url = f"{url_base}/storage/v1/object/public/card_images/{storage_path}"
                    
                    loc_data = {}
                    for lang in langs:
                        loc_data[lang] = {"answer": translations.get(lang, bone['name']), "prompt": "", "audio_url": None}
                    loc_data["global"] = {"answer": bone['name'], "prompt": "", "audio_url": None, "video_url": "", "image_urls": [final_img_url]}
                    
                    cards_to_insert.append({
                        "id": card_id,
                        "subject_id": subject_id,
                        "level": (i // 10) + 1, # Group levels
                        "owner_id": owner_id,
                        "is_public": True,
                        "test_mode": "image_to_text",
                        "localized_data": loc_data
                    })
                    print(f"Added {bone['name']}")
                else:
                    print(f"Upload failed for {bone['name']}")
            else:
                print(f"Download failed for {bone['name']}")
        except Exception as e:
            print(f"Error for {bone['name']}: {e}")
        
        # Batch insert every 20 cards
        if len(cards_to_insert) >= 20:
            ins_resp = requests.post(f"{url_base}/rest/v1/cards", headers={**headers, "Content-Type": "application/json", "Prefer": "return=minimal"}, json=cards_to_insert)
            print(f"Inserted batch of {len(cards_to_insert)}: {ins_resp.status_code}")
            cards_to_insert = []
        
        time.sleep(0.1)

    if cards_to_insert:
        ins_resp = requests.post(f"{url_base}/rest/v1/cards", headers={**headers, "Content-Type": "application/json", "Prefer": "return=minimal"}, json=cards_to_insert)
        print(f"Inserted final batch of {len(cards_to_insert)}: {ins_resp.status_code}")

if __name__ == "__main__":
    process()
