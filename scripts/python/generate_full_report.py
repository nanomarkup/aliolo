import requests
import json

URL = "https://mltdjjszycfmokwqsqxm.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
headers = {"apikey": KEY, "Authorization": "Bearer " + KEY, "Content-Type": "application/json"}

def list_all_files(bucket_id, prefix=""):
    all_files = []
    offset = 0
    limit = 1000
    
    while True:
        res = requests.post(f"{URL}/storage/v1/object/list/{bucket_id}", headers=headers, json={
            "prefix": prefix,
            "limit": limit,
            "offset": offset,
            "sortBy": {"column": "name", "order": "asc"}
        })
        
        if res.status_code != 200:
            print(f"Error listing files in {bucket_id} (prefix: {prefix}): {res.text}")
            break
            
        items = res.json()
        if not items:
            break
            
        for item in items:
            # If id is None, it's a folder
            if item.get('id') is None:
                new_prefix = f"{prefix}/{item['name']}" if prefix else item['name']
                all_files.extend(list_all_files(bucket_id, new_prefix))
            else:
                full_path = f"{prefix}/{item['name']}" if prefix else item['name']
                all_files.append(full_path)
        
        if len(items) < limit:
            break
        offset += limit
        
    return all_files

print("Regenerating ACCURATE Missing Media Report with full pagination...")
existing_images = set(list_all_files("card_images"))
existing_audio = set(list_all_files("card_audio"))

print(f"Found {len(existing_images)} total images in bucket.")
print(f"Found {len(existing_audio)} total audio files in bucket.")

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

missing_report = {
    "card_images": [],
    "card_audio": []
}

for card in all_cards:
    loc = card.get('localized_data') or {}
    answer = loc.get('global', {}).get('answer') or loc.get('en', {}).get('answer') or "Unknown"
    
    for lang, data in loc.items():
        if not isinstance(data, dict): continue
        
        # Check Images
        imgs = data.get('image_urls')
        if isinstance(imgs, list):
            for url in imgs:
                if "/card_images/" in url:
                    path = url.split("/card_images/")[1].split('?')[0]
                    if path not in existing_images:
                        missing_report["card_images"].append({
                            "card_id": card['id'],
                            "answer": answer,
                            "lang": lang,
                            "path": path,
                            "url": url
                        })
        
        # Check Audio
        aud = data.get('audio_url')
        if aud and "/card_audio/" in aud:
            path = aud.split("/card_audio/")[1].split('?')[0]
            if path not in existing_audio:
                missing_report["card_audio"].append({
                    "card_id": card['id'],
                    "answer": answer,
                    "lang": lang,
                    "path": path,
                    "url": aud
                })

with open("MISSING_MEDIA_REPORT.json", "w") as f:
    json.dump(missing_report, f, indent=2)

print(f"Report saved. {len(missing_report['card_images'])} images and {len(missing_report['card_audio'])} audio files truly missing.")
