import os
import json
import requests
import uuid
from datetime import datetime

# Supabase configuration
SUPABASE_URL = "https://mltdjjszycfmokwqsqxm.supabase.co"
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "YOUR_SECRET_KEY")
USER_ID = "f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac"
BUCKET_NAME = "card_images"

# Pillar mapping
PILLAR_MAP = {
    "engineering": 1,
    "human_body": 2,
    "humanities": 3,
    "leisure": 4,
    "nature": 5,
    "stem": 6,
    "world": 7,
    "languages": 8
}

def convert_to_map(data_list):
    """Converts ['EN: text', 'UK: text'] to {'en': 'text', 'uk': 'text'}"""
    res = {}
    for item in data_list:
        if ':' in item:
            lang, text = item.split(':', 1)
            res[lang.strip().lower()] = text.strip()
    return res

def upload_image(file_path, storage_path):
    """Uploads file to Supabase storage"""
    url = f"{SUPABASE_URL}/storage/v1/object/{BUCKET_NAME}/{storage_path}"
    with open(file_path, 'rb') as f:
        headers = {
            "Authorization": f"Bearer {SUPABASE_KEY}",
            "apikey": SUPABASE_KEY,
            "Content-Type": "image/jpeg"
        }
        res = requests.post(url, headers=headers, data=f)
        if res.status_code == 200:
            return f"{SUPABASE_URL}/storage/v1/object/public/{BUCKET_NAME}/{storage_path}"
        elif res.status_code == 400 and "already exists" in res.text:
             return f"{SUPABASE_URL}/storage/v1/object/public/{BUCKET_NAME}/{storage_path}"
        else:
            print(f"Failed to upload {file_path}: {res.status_code} {res.text}")
            return None

def upsert_subject(name, pillar_id, translations=None):
    """Upserts subject and returns its ID"""
    url = f"{SUPABASE_URL}/rest/v1/subjects"
    headers = {
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "apikey": SUPABASE_KEY,
        "Prefer": "return=representation,resolution=merge-duplicates",
        "Content-Type": "application/json"
    }
    
    payload = {
        "name": name,
        "pillar_id": pillar_id,
        "owner_id": USER_ID,
        "is_public": True,
        "translations": translations or {}
    }
    
    # Check if exists first to get ID, or use name/pillar_id for conflict
    res = requests.post(url, headers=headers, json=payload)
    if res.status_code in [200, 201]:
        data = res.json()
        if data:
            return data[0]['id']
    else:
        # Fallback to fetching by name and pillar_id
        res = requests.get(f"{url}?name=eq.{name}&pillar_id=eq.{pillar_id}", headers=headers)
        if res.status_code == 200:
            data = res.json()
            if data:
                return data[0]['id']
    
    print(f"Failed to upsert subject {name}: {res.status_code} {res.text}")
    return None

def insert_card(card_data):
    """Inserts card into cards table"""
    url = f"{SUPABASE_URL}/rest/v1/cards"
    headers = {
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "apikey": SUPABASE_KEY,
        "Prefer": "resolution=merge-duplicates",
        "Content-Type": "application/json"
    }
    res = requests.post(url, headers=headers, json=card_data)
    if res.status_code not in [200, 201, 204]:
        print(f"Failed to insert card {card_data['id']}: {res.status_code} {res.text}")
        return False
    return True

def migrate():
    base_dir = os.path.expanduser("~/.aliolo/cards")
    
    for pillar_folder in os.listdir(base_dir):
        pillar_path = os.path.join(base_dir, pillar_folder)
        if not os.path.isdir(pillar_path) or pillar_folder not in PILLAR_MAP:
            continue
            
        pillar_id = PILLAR_MAP[pillar_folder]
        print(f"\nProcessing Pillar: {pillar_folder} (ID: {pillar_id})")
        
        for subject_folder in os.listdir(pillar_path):
            subject_path = os.path.join(pillar_path, subject_folder)
            if not os.path.isdir(subject_path):
                continue
                
            print(f"  Processing Subject: {subject_folder}")
            
            # Read meta.json for translations
            translations = {}
            meta_path = os.path.join(subject_path, "meta.json")
            if os.path.exists(meta_path):
                with open(meta_path, 'r', encoding='utf-8') as f:
                    meta = json.load(f)
                    translations = meta.get("name", {})
            
            # Create subject
            subject_id = upsert_subject(subject_folder, pillar_id, translations)
            if not subject_id:
                continue
                
            # Process cards
            for filename in os.listdir(subject_path):
                if filename.endswith(".json") and filename != "meta.json":
                    card_id = filename[:-5]
                    json_path = os.path.join(subject_path, filename)
                    jpg_path = os.path.join(subject_path, f"{card_id}.jpg")
                    
                    if not os.path.exists(jpg_path):
                        print(f"    Missing JPG for card {card_id}")
                        continue
                        
                    with open(json_path, 'r', encoding='utf-8') as f:
                        data = json.load(f)
                        
                    # Upload image
                    storage_path = f"{USER_ID}/{subject_folder}/{card_id}.jpg"
                    image_url = upload_image(jpg_path, storage_path)
                    
                    if not image_url:
                        continue
                        
                    # Prepare card data
                    card_payload = {
                        "id": card_id,
                        "subject_id": subject_id,
                        "level": data.get("level", 1),
                        "prompts": convert_to_map(data.get("prompts", [])),
                        "answers": convert_to_map(data.get("answers", [])),
                        "video_url": data.get("videoUrl", ""),
                        "image_url": image_url,
                        "image_urls": [image_url],
                        "owner_id": USER_ID,
                        "is_public": True,
                        "is_deleted": False,
                        "updated_at": datetime.now().isoformat(),
                        "created_at": datetime.now().isoformat()
                    }
                    
                    if insert_card(card_payload):
                        # print(f"    Migrated card: {card_id}")
                        pass
                    else:
                        print(f"    Failed to migrate card: {card_id}")

    print("\nMigration Complete!")

if __name__ == "__main__":
    migrate()
