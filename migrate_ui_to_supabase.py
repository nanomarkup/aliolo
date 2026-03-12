import os
import json
import requests
from datetime import datetime

# Supabase configuration
SUPABASE_URL = "https://mltdjjszycfmokwqsqxm.supabase.co"
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "YOUR_SECRET_KEY")

def upsert_ui_translation(lang_code, translations):
    """Upserts UI translations into ui_translations table"""
    url = f"{SUPABASE_URL}/rest/v1/ui_translations"
    headers = {
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "apikey": SUPABASE_KEY,
        "Prefer": "resolution=merge-duplicates",
        "Content-Type": "application/json"
    }
    
    payload = {
        "id": lang_code,
        "translations": translations,
        "updated_at": datetime.now().isoformat()
    }
    
    res = requests.post(url, headers=headers, json=payload)
    if res.status_code not in [200, 201, 204]:
        print(f"Failed to upsert UI translation for {lang_code}: {res.status_code} {res.text}")
        return False
    return True

def migrate():
    lang_dir = "aliolo/assets/lang"
    if not os.path.exists(lang_dir):
        # Try local .aliolo folder if assets/lang is not available (though we just updated assets/lang)
        lang_dir = os.path.expanduser("~/.aliolo/lang")
        
    print(f"Migrating UI translations from: {lang_dir}")
    
    count = 0
    for filename in os.listdir(lang_dir):
        if filename.endswith(".json"):
            lang_code = filename[:-5]
            file_path = os.path.join(lang_dir, filename)
            
            with open(file_path, 'r', encoding='utf-8') as f:
                try:
                    translations = json.load(f)
                    if upsert_ui_translation(lang_code, translations):
                        print(f"  Migrated UI: {lang_code}")
                        count += 1
                except Exception as e:
                    print(f"  Error reading {filename}: {e}")

    print(f"\nUI Migration Complete! {count} languages updated.")

if __name__ == "__main__":
    migrate()
