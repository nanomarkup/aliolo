import requests
import os
import subprocess
import tempfile
import json

# Supabase Config
SB_URL = "https://mltdjjszycfmokwqsqxm.supabase.co"
SB_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
sb_headers = {"apikey": SB_KEY, "Authorization": f"Bearer {SB_KEY}"}

def get_referenced_files():
    print("Fetching database references...")
    all_cards = []
    offset = 0
    limit = 1000
    while True:
        url = f"{SB_URL}/rest/v1/cards?select=localized_data&offset={offset}&limit={limit}"
        res = requests.get(url, headers=sb_headers)
        data = res.json()
        if not data: break
        all_cards.extend(data)
        if len(data) < limit: break
        offset += limit
    
    files = []
    for c in all_cards:
        loc = c.get('localized_data') or {}
        for lang_data in loc.values():
            if not isinstance(lang_data, dict): continue
            
            # Images
            imgs = lang_data.get('image_urls')
            if isinstance(imgs, list):
                for img in imgs:
                    if "/card_images/" in img:
                        files.append(("card_images", "aliolo-media", img.split("/card_images/")[1].split('?')[0]))
            
            # Audio
            aud = lang_data.get('audio_url')
            if aud and "/card_audio/" in aud:
                files.append(("card_audio", "aliolo-media", aud.split("/card_audio/")[1].split('?')[0]))
            
            # Video
            vid = lang_data.get('video_url')
            if vid and "/card_videos/" in vid:
                files.append(("card_videos", "aliolo-media", vid.split("/card_videos/")[1].split('?')[0]))
                
    # Avatars
    res = requests.get(f"{SB_URL}/rest/v1/profiles?select=avatar_url", headers=sb_headers)
    for p in res.json():
        url = p.get('avatar_url')
        if url and "/avatars/" in url:
            files.append(("avatars", "aliolo-avatars", url.split("/avatars/")[1].split('?')[0]))
            
    return list(set(files))

def migrate_file(sb_bucket, r2_bucket, path):
    r2_path = f"{sb_bucket}/{path}" if r2_bucket == "aliolo-media" else path
    download_url = f"{SB_URL}/storage/v1/object/public/{sb_bucket}/{path}"
    
    try:
        # Check if exists in R2 first to skip
        check_cmd = ["wrangler", "r2", "object", "get", f"{r2_bucket}/{r2_path}"]
        check_res = subprocess.run(check_cmd, capture_output=True)
        if check_res.returncode == 0:
            return True # Already exists
            
        resp = requests.get(download_url, timeout=30)
        if resp.status_code != 200: return False
        
        with tempfile.NamedTemporaryFile(delete=False) as tmp:
            tmp.write(resp.content)
            tmp_path = tmp.name
        
        try:
            cmd = ["wrangler", "r2", "object", "put", f"{r2_bucket}/{r2_path}", f"--file={tmp_path}"]
            subprocess.run(cmd, check=True, capture_output=True)
            print(f"  [OK] Migrated {r2_path}")
            return True
        finally:
            if os.path.exists(tmp_path): os.remove(tmp_path)
    except: return False

def main():
    files = get_referenced_files()
    print(f"Total files to migrate: {len(files)}")
    
    count = 0
    for sb_bucket, r2_bucket, path in files:
        if migrate_file(sb_bucket, r2_bucket, path):
            count += 1
            if count % 10 == 0:
                print(f"Progress: {count}/{len(files)}")
                
    print(f"\nMigration complete. {count} files verified in R2.")

if __name__ == "__main__":
    main()
