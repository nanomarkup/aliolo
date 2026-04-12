import requests
import json

URL = "https://mltdjjszycfmokwqsqxm.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
headers = {"apikey": KEY, "Authorization": "Bearer " + KEY, "Content-Type": "application/json"}

def list_all_files(bucket_id, path=""):
    files = []
    res = requests.post(f"{URL}/storage/v1/object/list/{bucket_id}", headers=headers, json={
        "prefix": path,
        "limit": 1000,
        "offset": 0,
        "sortBy": {"column": "name", "order": "asc"}
    })
    if res.status_code != 200: return []
    items = res.json()
    for item in items:
        full_name = f"{path}/{item['name']}" if path else item['name']
        if item.get('id') is None: # Folder
            files.extend(list_all_files(bucket_id, full_name))
        else:
            files.append(full_name)
    return files

# 1. Fetch all files currently in storage
existing_images = set(list_all_files("card_images"))
existing_audio = set(list_all_files("card_audio"))

# 2. Fetch ALL cards using pagination
all_cards = []
offset = 0
limit = 1000
while True:
    res = requests.get(f"{URL}/rest/v1/cards?select=id,localized_data&offset={offset}&limit={limit}", headers=headers)
    data = res.json()
    if not data: break
    all_cards.extend(data)
    if len(data) < limit: break
    offset += limit

broken_images_count = 0
broken_audio_count = 0
total_cards_with_missing_media = 0

for card in all_cards:
    loc = card.get('localized_data') or {}
    card_has_missing = False
    
    for lang, data in loc.items():
        if not isinstance(data, dict): continue
        
        # Check Images
        imgs = data.get('image_urls')
        if isinstance(imgs, list):
            for url in imgs:
                if "/card_images/" in url:
                    path = url.split("/card_images/")[1].split('?')[0]
                    if path not in existing_images:
                        broken_images_count += 1
                        card_has_missing = True
        
        # Check Audio
        aud = data.get('audio_url')
        if aud and "/card_audio/" in aud:
            path = aud.split("/card_audio/")[1].split('?')[0]
            if path not in existing_audio:
                broken_audio_count += 1
                card_has_missing = True

    if card_has_missing:
        total_cards_with_missing_media += 1

print(f"TOTAL_CARDS: {len(all_cards)}")
print(f"CARDS_WITH_MISSING_MEDIA: {total_cards_with_missing_media}")
print(f"TOTAL_MISSING_IMAGES: {broken_images_count}")
print(f"TOTAL_MISSING_AUDIO: {broken_audio_count}")
