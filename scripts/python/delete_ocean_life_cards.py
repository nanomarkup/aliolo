import requests
import json

url_base = "https://mltdjjszycfmokwqsqxm.supabase.co"
apikey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
headers = {
    "apikey": apikey,
    "Authorization": f"Bearer {apikey}"
}

subject_id = "2450ccd1-b439-4ed1-8280-30de3f41e400"

def delete_cards():
    # 1. Fetch all cards for the subject
    resp = requests.get(f"{url_base}/rest/v1/cards?subject_id=eq.{subject_id}&select=id,localized_data", headers=headers)
    if resp.status_code != 200:
        print(f"Failed to fetch cards: {resp.text}")
        return
    
    cards = resp.json()
    print(f"Found {len(cards)} cards to delete.")
    
    files_to_delete = []
    
    for card in cards:
        loc_data = card.get('localized_data', {})
        
        # Extract image URLs from global
        global_data = loc_data.get('global', {})
        image_urls = global_data.get('image_urls', [])
        for url in image_urls:
            if 'storage/v1/object/public/card_images/' in url:
                path = url.split('card_images/')[-1]
                files_to_delete.append(path)
        
        # Extract audio URLs from all languages
        for lang in loc_data:
            if lang == 'global': continue
            audio_url = loc_data[lang].get('audio_url')
            if audio_url and 'storage/v1/object/public/card_audio/' in audio_url:
                path = audio_url.split('card_audio/')[-1]
                # Note: Assuming audio bucket is card_audio
                # We need to be careful about bucket names
                pass 

    # 2. Delete files from Storage (Bulk delete is supported by Supabase)
    if files_to_delete:
        print(f"Deleting {len(files_to_delete)} image files...")
        # Supabase Storage bulk delete: POST /storage/v1/object/card_images
        # body: { "prefixes": ["path/to/file1", "path/to/file2"] }
        del_resp = requests.delete(f"{url_base}/storage/v1/object/card_images", 
                                 headers=headers, 
                                 json={"prefixes": files_to_delete})
        print(f"Storage deletion status: {del_resp.status_code}")
        if del_resp.status_code >= 400:
            print(del_resp.text)

    # 3. Delete cards from Database
    if cards:
        print("Deleting cards from database...")
        del_resp = requests.delete(f"{url_base}/rest/v1/cards?subject_id=eq.{subject_id}", headers=headers)
        print(f"Database deletion status: {del_resp.status_code}")
        if del_resp.status_code >= 400:
            print(del_resp.text)

if __name__ == "__main__":
    delete_cards()
