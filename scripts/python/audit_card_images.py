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
    
    if res.status_code != 200:
        return []
        
    items = res.json()
    for item in items:
        full_name = f"{path}/{item['name']}" if path else item['name']
        if item.get('id') is None: # Folder
            files.extend(list_all_files(bucket_id, full_name))
        else:
            files.append(full_name)
    return files

print("--- Card Image Link Audit ---")

# 1. Fetch all files in card_images bucket
print("Listing all files in 'card_images' bucket...")
existing_files = set(list_all_files("card_images"))
print(f"Found {len(existing_files)} files in storage.")

# 2. Fetch all cards
print("Fetching all cards from database...")
res = requests.get(f"{URL}/rest/v1/cards?select=id,localized_data", headers=headers)
cards = res.json()
print(f"Found {len(cards)} cards in database.")

broken_cards = []

for card in cards:
    card_id = card['id']
    loc = card.get('localized_data') or {}
    
    missing_for_card = []
    
    for lang, data in loc.items():
        if not isinstance(data, dict): continue
        imgs = data.get('image_urls')
        if not isinstance(imgs, list): continue
        
        for url in imgs:
            if not url: continue
            
            # Extract path from URL
            # .../storage/v1/object/public/card_images/PATH_HERE
            target_marker = "/card_images/"
            if target_marker in url:
                path = url.split(target_marker)[1].split('?')[0]
                if path not in existing_files:
                    missing_for_card.append({"lang": lang, "url": url, "path": path})
            else:
                # External URL or different bucket?
                pass

    if missing_for_card:
        # Get English name for context
        answer = loc.get('global', {}).get('answer') or loc.get('en', {}).get('answer') or "Unknown"
        broken_cards.append({
            "id": card_id,
            "answer": answer,
            "missing": missing_for_card
        })

print("\n--- Audit Results ---")
if not broken_cards:
    print("All card image links are valid! No missing files found.")
else:
    print(f"Found {len(broken_cards)} cards with broken image links.")
    for bc in broken_cards:
        print(f"\nCard: {bc['answer']} ({bc['id']})")
        for m in bc['missing']:
            print(f"  [MISSING] {m['lang']}: {m['path']}")

# Save broken links to a file for review
with open("broken_image_links.json", "w") as f:
    json.dump(broken_cards, f, indent=2)
print("\nDetailed list of broken links saved to broken_image_links.json")
