import requests
import json

url_base = "https://mltdjjszycfmokwqsqxm.supabase.co"
apikey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
headers = {
    "apikey": apikey,
    "Authorization": f"Bearer {apikey}"
}

subject_id = "8db933e6-8906-4e4b-86f5-7c863fe1ef01"

def delete_subject_cards():
    # 1. Fetch all cards
    resp = requests.get(f"{url_base}/rest/v1/cards?subject_id=eq.{subject_id}&select=id,localized_data", headers=headers)
    if resp.status_code != 200:
        print(f"Failed to fetch cards: {resp.text}")
        return
    
    cards = resp.json()
    print(f"Found {len(cards)} cards to delete.")
    
    image_files = []
    audio_files = []
    
    for card in cards:
        loc_data = card.get('localized_data', {})
        
        # Images
        global_data = loc_data.get('global', {})
        image_urls = global_data.get('image_urls', [])
        for url in image_urls:
            if 'card_images/' in url:
                path = url.split('card_images/')[-1].split('?')[0]
                image_files.append(path)
        
        # Audio
        for lang in loc_data:
            if lang == 'global': continue
            audio_url = loc_data[lang].get('audio_url')
            if audio_url and 'card_audio/' in audio_url:
                path = audio_url.split('card_audio/')[-1].split('?')[0]
                audio_files.append(path)

    # 2. Delete files from Storage
    if image_files:
        print(f"Deleting {len(image_files)} image files...")
        requests.delete(f"{url_base}/storage/v1/object/card_images", headers=headers, json={"prefixes": list(set(image_files))})
    
    if audio_files:
        print(f"Deleting {len(audio_files)} audio files...")
        requests.delete(f"{url_base}/storage/v1/object/card_audio", headers=headers, json={"prefixes": list(set(audio_files))})

    # 3. Delete cards from Database
    if cards:
        print("Deleting cards from database...")
        del_resp = requests.delete(f"{url_base}/rest/v1/cards?subject_id=eq.{subject_id}", headers=headers)
        print(f"Database deletion status: {del_resp.status_code}")

if __name__ == "__main__":
    delete_subject_cards()
