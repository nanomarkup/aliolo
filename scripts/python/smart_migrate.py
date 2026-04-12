import os
import json
import time
import shutil
import subprocess

ROOT_DIR = "./assets/aliolo_images_f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac/f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac"
DEST_DIR = "./assets/cards"
BASE_URL = "https://aliolo.com/storage/v1/object/public/card_images"
CARDS_JSON = "all_cards.json"
SQL_FILE = "update_flag_urls.sql"

def get_timestamp():
    return int(time.time() * 1000)

def smart_migrate():
    with open(CARDS_JSON, 'r') as f:
        data = json.load(f)
        rows = data[0]['results']

    print(f"Loaded {len(rows)} cards from database.")

    # Build a map of filename (lowercase, no ext) to file path
    file_map = {}
    for root, dirs, files in os.walk(ROOT_DIR):
        for f in files:
            name_no_ext = os.path.splitext(f)[0].lower()
            file_map[name_no_ext] = os.path.join(root, f)

    print(f"Mapped {len(file_map)} local files.")

    sql_statements = []
    count = 0
    timestamp = get_timestamp()

    for row in rows:
        card_id = row['id']
        loc_data = json.loads(row['localized_data'])
        
        # We try to match by English answer
        en_data = loc_data.get('en', {})
        en_answer = en_data.get('answer', '').strip().lower()
        
        # Also try global answer
        global_data = loc_data.get('global', {})
        global_answer = global_data.get('answer', '').strip().lower()
        
        match_path = None
        
        # 1. Try match by ID (already handled by previous script mostly, but for completeness)
        if card_id.lower() in file_map:
            match_path = file_map[card_id.lower()]
        # 2. Try match by English answer
        elif en_answer and en_answer in file_map:
            match_path = file_map[en_answer]
        # 3. Try match by global answer
        elif global_answer and global_answer in file_map:
            match_path = file_map[global_answer]

        if match_path:
            ext = os.path.splitext(match_path)[1].lower()
            new_filename = f"global_{timestamp}{ext}"
            
            # Create destination: assets/cards/{id}/
            card_dest_dir = os.path.join(DEST_DIR, card_id)
            os.makedirs(card_dest_dir, exist_ok=True)
            
            # Copy file
            dest_file_path = os.path.join(card_dest_dir, new_filename)
            shutil.copy2(match_path, dest_file_path)
            
            # URL
            full_url = f"{BASE_URL}/cards/{card_id}/{new_filename}"
            
            # SQL - We update the global images
            sql = f"UPDATE cards SET localized_data = json_set(localized_data, '$.global.image_urls', json_array('{full_url}')) WHERE id = '{card_id}';"
            sql_statements.append(sql)
            count += 1

    with open(SQL_FILE, 'w') as f:
        f.write("\n".join(sql_statements))

    print(f"✅ Reorganized {count} matching images.")
    print(f"SQL file generated: {SQL_FILE}")

if __name__ == "__main__":
    smart_migrate()
