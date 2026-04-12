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

owner_id = "f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac"
langs = ['ar', 'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'fi', 'fr', 'ga', 'hi', 'hr', 'hu', 'id', 'it', 'ja', 'ko', 'lt', 'lv', 'mt', 'nl', 'pl', 'pt', 'ro', 'sk', 'sl', 'sv', 'tl', 'tr', 'uk', 'vi', 'zh']
USER_AGENT = "AlioloBot/1.0 (https://aliolo.com; hello@aliolo.com)"

# 1. Update AI Card (ID: a1dd303d-f086-40da-b453-94ff6f4d0526)
def get_wikipedia_translations(title):
    wiki_url = "https://en.wikipedia.org/w/api.php"
    params = {"action": "query", "prop": "langlinks", "titles": title, "lllimit": 500, "format": "json"}
    try:
        resp = requests.get(wiki_url, params=params, headers={"User-Agent": USER_AGENT}).json()
        pages = resp.get("query", {}).get("pages", {})
        translations = { 'en': title }
        for pid in pages:
            links = pages[pid].get("langlinks", [])
            for link in links:
                lang = link.get("lang")
                val = link.get("*")
                if lang in langs: translations[lang] = val
                elif lang == 'fil' and 'tl' in langs: translations['tl'] = val
                elif lang == 'zh-hans' and 'zh' in langs: translations['zh'] = val
        return translations
    except: return { 'en': title }

def fix_ai_card():
    card_id = "a1dd303d-f086-40da-b453-94ff6f4d0526"
    print("Fixing AI card translations and image...")
    trans = get_wikipedia_translations("Artificial intelligence")
    
    # Image for AI
    img_url = "https://upload.wikimedia.org/wikipedia/commons/thumb/9/94/Human_Brain_with_Digital_Nodes.jpg/1000px-Human_Brain_with_Digital_Nodes.jpg"
    i_resp = requests.get(img_url, headers={"User-Agent": USER_AGENT})
    
    final_img_url = ""
    if i_resp.status_code == 200:
        storage_path = f"{owner_id}/Tech Categories/{card_id}.jpg"
        upload_url = f"{url_base}/storage/v1/object/card_images/{storage_path}"
        requests.delete(upload_url, headers=headers)
        up_resp = requests.post(upload_url, headers={**headers, "Content-Type": "image/jpeg"}, data=i_resp.content)
        if up_resp.status_code in [200, 201]:
            final_img_url = f"{url_base}/storage/v1/object/public/card_images/{storage_path}"

    loc_data = {}
    for lang in langs:
        name = trans.get(lang, "Artificial intelligence")
        loc_data[lang] = {"answer": name, "prompt": "", "audio_url": None}
    loc_data["global"] = {"answer": "Artificial intelligence", "prompt": "", "audio_url": None, "video_url": "", "image_urls": [final_img_url] if final_img_url else []}
    
    requests.patch(f"{url_base}/rest/v1/cards?id=eq.{card_id}", headers=headers, json={"localized_data": loc_data})

# 2. Update Computing, Gaming, Smart healthcare with better images
def update_others():
    updates = [
        {"id": "3f75ff1a-b649-4202-9229-d1a0a9175ce0", "name": "Computing", "wiki_img": "Quantum_computer_at_NASA_Ames.jpg"},
        {"id": "cd260410-df37-4360-9b3e-073f9091823c", "name": "Gaming", "wiki_img": "Steam_Deck_with_dock.jpg"},
        {"id": "0576b629-f79c-46ea-b8de-aac29ae02df5", "name": "Smart healthcare", "wiki_img": "Operation_Room_Robotic_Surgery.jpg"}
    ]
    
    for up in updates:
        print(f"Updating image for {up['name']}...")
        # Get thumb URL for better reliability
        # Actually let's use direct if possible or search
        # Manual known good URLs
        img_urls = {
            "Computing": "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e3/Quantum_computer_at_NASA_Ames.jpg/1000px-Quantum_computer_at_NASA_Ames.jpg",
            "Gaming": "https://upload.wikimedia.org/wikipedia/commons/thumb/5/5e/Steam_Deck_with_dock.jpg/1000px-Steam_Deck_with_dock.jpg",
            "Smart healthcare": "https://upload.wikimedia.org/wikipedia/commons/thumb/4/49/Operation_Room_Robotic_Surgery.jpg/1000px-Operation_Room_Robotic_Surgery.jpg"
        }
        
        url = img_urls[up['name']]
        i_resp = requests.get(url, headers={"User-Agent": USER_AGENT})
        if i_resp.status_code == 200:
            storage_path = f"{owner_id}/Tech Categories/{up['id']}.jpg"
            upload_url = f"{url_base}/storage/v1/object/card_images/{storage_path}"
            requests.delete(upload_url, headers=headers)
            up_resp = requests.post(upload_url, headers={**headers, "Content-Type": "image/jpeg"}, data=i_resp.content)
            
            if up_resp.status_code in [200, 201]:
                final_img_url = f"{url_base}/storage/v1/object/public/card_images/{storage_path}"
                
                # We need current loc_data to preserve translations
                c_resp = requests.get(f"{url_base}/rest/v1/cards?id=eq.{up['id']}", headers=headers).json()[0]
                loc_data = c_resp['localized_data']
                loc_data['global']['image_urls'] = [final_img_url]
                requests.patch(f"{url_base}/rest/v1/cards?id=eq.{up['id']}", headers=headers, json={"localized_data": loc_data})
                print(f"Updated {up['name']}")

if __name__ == "__main__":
    fix_ai_card()
    update_others()
