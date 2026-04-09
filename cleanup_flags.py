import requests
import json

SUPABASE_URL = "https://mltdjjszycfmokwqsqxm.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
SUBJECT_ID = "35b2f5c1-10be-4c1d-b915-1159ef35fe26"

headers = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json"
}

def cleanup():
    # 1. Find all cards
    url = f"{SUPABASE_URL}/rest/v1/cards?subject_id=eq.{SUBJECT_ID}&select=id,localized_data"
    response = requests.get(url, headers=headers)
    if response.status_code != 200:
        print(f"Error fetching cards: {response.text}")
        return

    cards = response.json()
    print(f"Found {len(cards)} cards.")

    # 2. Extract media file paths
    image_paths = set()
    audio_paths = set()

    for card in cards:
        localized_data = card.get("localized_data", {})
        if not localized_data:
            continue
        
        # Check all languages in localized_data
        for lang, data in localized_data.items():
            if isinstance(data, dict):
                image_url = data.get("image_url")
                if image_url:
                    # Supabase storage URLs usually look like:
                    # https://.../storage/v1/object/public/card_images/f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac/Flags of the World/Albania.png
                    if "card_images/" in image_url:
                        path = image_url.split("card_images/")[1]
                        image_paths.add(path)
                
                audio_url = data.get("audio_url")
                if audio_url:
                    if "card_audio/" in audio_url:
                        path = audio_url.split("card_audio/")[1]
                        audio_paths.add(path)

    print(f"Images to delete: {len(image_paths)}")
    print(f"Audio to delete: {len(audio_paths)}")

    # 3. Delete these files from Supabase storage
    for path in image_paths:
        storage_url = f"{SUPABASE_URL}/storage/v1/object/card_images/{path}"
        res = requests.delete(storage_url, headers=headers)
        if res.status_code == 200:
            print(f"Deleted image: {path}")
        else:
            print(f"Failed to delete image {path}: {res.text}")

    for path in audio_paths:
        storage_url = f"{SUPABASE_URL}/storage/v1/object/card_audio/{path}"
        res = requests.delete(storage_url, headers=headers)
        if res.status_code == 200:
            print(f"Deleted audio: {path}")
        else:
            print(f"Failed to delete audio {path}: {res.text}")

    # 4. Delete all card records
    delete_url = f"{SUPABASE_URL}/rest/v1/cards?subject_id=eq.{SUBJECT_ID}"
    res = requests.delete(delete_url, headers=headers)
    if res.status_code in [200, 204]:
        print("Deleted all card records.")
    else:
        print(f"Failed to delete card records: {res.text}")

if __name__ == "__main__":
    cleanup()
