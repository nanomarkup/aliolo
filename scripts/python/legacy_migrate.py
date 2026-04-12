import os
import json
import time
import shutil

ROOT_DIR = "./assets/aliolo_images_f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac/f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac"
DEST_DIR = "./assets/cards"
BASE_URL = "https://aliolo.com/storage/v1/object/public/card_images"
CARDS_JSON = "all_cards.json"
SQL_FILE = "update_legacy_ids.sql"

def get_timestamp():
    return int(time.time() * 1000)

def legacy_migrate():
    with open(CARDS_JSON, 'r') as f:
        data = json.load(f)
        rows = data[0]['results']

    print(f"Loaded {len(rows)} cards from database.")

    # Build a map of ALL local files by filename (lowercase)
    file_map = {}
    for root, dirs, files in os.walk(ROOT_DIR):
        for f in files:
            file_map[f.lower()] = os.path.join(root, f)

    print(f"Mapped {len(file_map)} local files.")

    sql_statements = []
    count = 0
    timestamp = get_timestamp()

    for row in rows:
        new_id = row['id']
        loc_data = json.loads(row['localized_data'])
        
        # Check if already migrated to aliolo.com
        global_data = loc_data.get('global', {})
        img_urls = global_data.get('image_urls', [])
        if img_urls and 'aliolo.com' in img_urls[0]:
            continue

        # Look for the OLD filename in any language's image_urls
        old_filename = None
        for lang_code, data in loc_data.items():
            if not isinstance(data, dict): continue
            urls = data.get('image_urls', [])
            if not urls: continue
            
            for url in urls:
                if 'supabase.co' in url or 'aliolo-backend' in url:
                    # Extract filename from end of URL
                    # e.g. .../Flags%20of%20International%20Organizations/75862fa6-e5be-44db-8027-cf3f67928d39.png
                    fname = url.split('/')[-1].replace('%20', ' ')
                    if fname.lower() in file_map:
                        old_filename = fname.lower()
                        break
            if old_filename: break

        if old_filename:
            match_path = file_map[old_filename]
            ext = os.path.splitext(match_path)[1].lower()
            new_filename = f"global_{timestamp}{ext}"
            
            # Create destination
            card_dest_dir = os.path.join(DEST_DIR, new_id)
            os.makedirs(card_dest_dir, exist_ok=True)
            
            # Copy
            dest_file_path = os.path.join(card_dest_dir, new_filename)
            shutil.copy2(match_path, dest_file_path)
            
            # URL
            full_url = f"{BASE_URL}/cards/{new_id}/{new_filename}"
            
            # SQL
            sql = f"UPDATE cards SET localized_data = json_set(localized_data, '$.global.image_urls', json_array('{full_url}')) WHERE id = '{new_id}';"
            sql_statements.append(sql)
            count += 1

    if sql_statements:
        with open(SQL_FILE, 'w') as f:
            f.write("\n".join(sql_statements))
        print(f"✅ Reorganized {count} cards using legacy URL matching.")
        print(f"SQL file generated: {SQL_FILE}")
    else:
        print("No matches found using legacy URL matching.")

if __name__ == "__main__":
    legacy_migrate()
