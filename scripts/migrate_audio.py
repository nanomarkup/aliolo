import json
import subprocess
import os
import requests
import sys

# Configuration
SUPABASE_PROJECT_REF = "mltdjjszycfmokwqsqxm"
SUPABASE_SERVICE_ROLE = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
CF_DOMAIN = "aliolo.com"
CF_STORAGE_BASE = f"https://{CF_DOMAIN}/storage/v1/object/public/"
R2_BUCKET = "aliolo-media"

SUPABASE_PUBLIC_BASE = f"https://{SUPABASE_PROJECT_REF}.supabase.co/storage/v1/object/public/"

def run_query(query):
    result = subprocess.run(
        ["npx", "wrangler", "d1", "execute", "aliolo-db", "--remote", "--command", query, "--json", "-y"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"D1 Query Error: {result.stderr}")
        return None
    try:
        data = json.loads(result.stdout)
        if isinstance(data, list) and len(data) > 0:
            return data[0].get('results', [])
        return []
    except:
        # Fallback for plain text or mixed output
        lines = result.stdout.strip().split('\n')
        for line in lines:
            try:
                data = json.loads(line)
                if isinstance(data, list) and len(data) > 0:
                    return data[0].get('results', [])
                elif isinstance(data, dict):
                     return data.get('results', [])
            except:
                continue
        return []

def upload_to_r2(local_path, r2_path):
    # npx wrangler r2 object put aliolo-media/cards/ID/audio_lang.mp3 --file=local_path
    cmd = [
        "npx", "wrangler", "r2", "object", "put",
        f"{R2_BUCKET}/{r2_path}",
        f"--file={local_path}"
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"R2 Upload Error: {result.stderr}")
        return False
    return True

def migrate_audio():
    print("Fetching cards with audio...")
    # Find cards that have audio_url in their localized_data
    # and specifically target those that haven't been migrated to the final /card_audio/cards/ pattern yet
    cards = run_query("SELECT id, localized_data FROM cards WHERE localized_data LIKE '%audio_url%' AND localized_data NOT LIKE '%/card_audio/cards/%';")
    
    if not cards:
        print("No cards with pending audio migration found.")
        return

    total_cards = len(cards)
    print(f"Processing {total_cards} cards...")

    for idx, card in enumerate(cards):
        card_id = card['id']
        try:
            localized_data = json.loads(card['localized_data'])
        except:
            print(f"[{idx+1}/{total_cards}] Skip card {card_id}: JSON parse error")
            continue

        updated = False
        print(f"[{idx+1}/{total_cards}] Card {card_id}...", end="", flush=True)

        for lang, data in localized_data.items():
            if 'audio_url' in data and data['audio_url'] and '/card_audio/cards/' not in data['audio_url']:
                old_url = data['audio_url']
                
                # Check if it's already a CF URL or still Supabase
                if CF_DOMAIN in old_url:
                    path_part = old_url.replace(CF_STORAGE_BASE, "")
                    supabase_url = SUPABASE_PUBLIC_BASE + path_part
                elif "supabase.co" in old_url:
                    supabase_url = old_url
                else:
                    continue

                ext = old_url.split('.')[-1].split('?')[0]
                if len(ext) > 4: ext = "mp3"
                
                new_r2_path = f"cards/{card_id}/audio_{lang}.{ext}"
                new_cf_url = f"{CF_STORAGE_BASE}card_audio/{new_r2_path}"

                temp_file = f"temp_audio_{card_id}_{lang}.{ext}"
                try:
                    headers = {"Authorization": f"Bearer {SUPABASE_SERVICE_ROLE}"}
                    resp = requests.get(supabase_url, headers=headers, timeout=30)
                    if resp.status_code == 200:
                        with open(temp_file, "wb") as f:
                            f.write(resp.content)
                        
                        if upload_to_r2(temp_file, new_r2_path):
                            localized_data[lang]['audio_url'] = new_cf_url
                            updated = True
                        os.remove(temp_file)
                    else:
                        # If download failed with 404, maybe it's already gone or path is different
                        # We don't mark as updated
                        pass
                except Exception as e:
                    if os.path.exists(temp_file): os.remove(temp_file)

        if updated:
            new_json = json.dumps(localized_data).replace("'", "''")
            update_res = subprocess.run(
                ["npx", "wrangler", "d1", "execute", "aliolo-db", "--remote", "--command", 
                 f"UPDATE cards SET localized_data = '{new_json}' WHERE id = '{card_id}';", "-y"],
                capture_output=True, text=True
            )
            if update_res.returncode == 0:
                print(" Done.")
            else:
                # If D1 is busy, we might need a small sleep and retry or just continue
                print(f" Update failed (D1 busy).")
        else:
            print(" No changes.")

if __name__ == "__main__":
    migrate_audio()
