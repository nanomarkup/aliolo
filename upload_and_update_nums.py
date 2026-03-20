import urllib.request
import json
import ssl
import os

SUPABASE_URL = "https://mltdjjszycfmokwqsqxm.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
USER_ID = "f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac"
SUBJECT_ID = "cb04da1c-9820-4e61-ae6b-bc7ed07eeb93"

HEADERS = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}"
}

context = ssl._create_unverified_context()

def upload_file(local_path, remote_path):
    with open(local_path, 'rb') as f:
        file_data = f.read()
    
    url = f"{SUPABASE_URL}/storage/v1/object/card_images/{remote_path}"
    req = urllib.request.Request(url, data=file_data, headers={
        **HEADERS,
        "Content-Type": "image/png"
    }, method="POST")
    
    try:
        urllib.request.urlopen(req, context=context)
        return True
    except Exception as e:
        # If exists, try to overwrite or just ignore
        if "Duplicate" in str(e) or "409" in str(e):
            return True
        print(f"Error uploading {local_path}: {e}")
        return False

def update_cards():
    # 1. Fetch all cards for the subject
    req = urllib.request.Request(f"{SUPABASE_URL}/rest/v1/cards?subject_id=eq.{SUBJECT_ID}&select=id,localized_data", headers=HEADERS)
    with urllib.request.urlopen(req, context=context) as response:
        cards = json.loads(response.read().decode())
    
    print(f"Updating {len(cards)} cards...")
    
    langs = ['ar', 'hi', 'zh', 'ja', 'ko']
    
    for card in cards:
        card_id = card['id']
        loc_data = card['localized_data']
        
        # Determine the number from global answer or other means
        # In this subject, cards are likely 1-20
        # Let's try to find which number this card represents
        ans = loc_data.get('global', {}).get('answer', '')
        # ANS might be "One", "Two" or "1", "2"
        # Based on previous research: Answer: Nineteen, Answer: Twenty...
        
        num_map_inv = {
            "One": 1, "Two": 2, "Three": 3, "Four": 4, "Five": 5,
            "Six": 6, "Seven": 7, "Eight": 8, "Nine": 9, "Ten": 10,
            "Eleven": 11, "Twelve": 12, "Thirteen": 13, "Fourteen": 14, "Fifteen": 15,
            "Sixteen": 16, "Seventeen": 17, "Eighteen": 18, "Nineteen": 19, "Twenty": 20,
            "1": 1, "2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7, "8": 8, "9": 9, "10": 10,
            "11": 11, "12": 12, "13": 13, "14": 14, "15": 15, "16": 16, "17": 17, "18": 18, "19": 19, "20": 20
        }
        
        num_val = num_map_inv.get(ans)
        if not num_val:
            # Try to match by index if needed, but answer should work
            print(f"Could not determine number for card {card_id} with answer '{ans}'")
            continue
            
        updated = False
        for lang in langs:
            remote_path = f"{USER_ID}/numbers/{lang}/num_{num_val}.png"
            local_path = f"temp_nums/num_{lang}_{num_val}.png"
            
            if os.path.exists(local_path):
                if upload_file(local_path, remote_path):
                    if lang not in loc_data:
                        loc_data[lang] = {}
                    
                    # Update localized data with the new image URL
                    img_url = f"{SUPABASE_URL}/storage/v1/object/public/card_images/{remote_path}"
                    loc_data[lang]['image_urls'] = [img_url]
                    updated = True
        
        if updated:
            # PATCH the card
            patch_url = f"{SUPABASE_URL}/rest/v1/cards?id=eq.{card_id}"
            patch_req = urllib.request.Request(patch_url, data=json.dumps({"localized_data": loc_data}).encode("utf-8"), headers={
                **HEADERS,
                "Content-Type": "application/json",
                "Prefer": "return=minimal"
            }, method="PATCH")
            urllib.request.urlopen(patch_req, context=context)
            print(f"Updated card {card_id} (Number {num_val})")

if __name__ == "__main__":
    update_cards()
