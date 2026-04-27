import json
import subprocess
import csv
import unicodedata
import time
from deep_translator import GoogleTranslator
from concurrent.futures import ThreadPoolExecutor, as_completed

DB_NAME = "aliolo-db"
SUBJECT_IDS = [
    'de04da1c-9820-4e61-ae6b-bc7ed07eeb93', # Addition 0-10
    '5e81da1f-f92c-44d2-b3cd-f921d05425df', # Addition 11-20
    'ce04da1c-9820-4e61-ae6b-bc7ed07eeb93', # Subtraction 0-10
    'f59a0f9c-5d6d-4f2d-b426-eb9ca6bf2782'  # Subtraction 11-20
]
COLLECTION_IDS = [
    'e104da1c-9820-4e61-ae6b-bc7ed07eeb93', # Subtraction 20
    'd104da1c-9820-4e61-ae6b-bc7ed07eeb93', # Addition 20
    'f204da1c-9820-4e61-ae6b-bc7ed07eeb93'  # Add & Subtract 20
]

def run_wrangler(sql):
    cmd = ["npx", "wrangler", "d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        return []
    try:
        return json.loads(res.stdout)[0]["results"]
    except:
        return []

def normalize(text):
    if not text: return ""
    text = "".join(ch for ch in text if not unicodedata.category(ch).startswith('P'))
    return unicodedata.normalize("NFC", text).strip().lower()

def main():
    print("Fetching subjects, collections and cards...")
    s_ids = "', '".join(SUBJECT_IDS)
    c_ids = "', '".join(COLLECTION_IDS)
    
    subjects = run_wrangler(f"SELECT id, name, names, description, descriptions FROM subjects WHERE id IN ('{s_ids}')")
    collections = run_wrangler(f"SELECT id, name, names, description, descriptions FROM collections WHERE id IN ('{c_ids}')")
    cards = run_wrangler(f"SELECT id, subject_id, answer, answers, prompt, prompts, display_text, display_texts FROM cards WHERE subject_id IN ('{s_ids}')")
    
    diffs = []
    locales = ['ar', 'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'fi', 'fr', 'ga', 'hi', 'hr', 'hu', 'id', 'it', 'ja', 'ko', 'lt', 'lv', 'mt', 'nl', 'pl', 'pt', 'ro', 'sk', 'sl', 'sv', 'tl', 'tr', 'uk', 'vi', 'zh']
    
    all_tasks = []

    # 1. Subject Metadata tasks
    for s in subjects:
        s_names = json.loads(s['names'] or '{}')
        s_descs = json.loads(s['descriptions'] or '{}')
        for loc in locales:
            if loc in s_names:
                all_tasks.append((f"SUBJ:{s['id']}", "name", loc, s['name'], s_names[loc]))
            if loc in s_descs:
                all_tasks.append((f"SUBJ:{s['id']}", "description", loc, s['description'], s_descs[loc]))

    # 2. Collection Metadata tasks
    for c in collections:
        c_names = json.loads(c['names'] or '{}')
        c_descs = json.loads(c['descriptions'] or '{}')
        for loc in locales:
            if loc in c_names:
                all_tasks.append((f"COLL:{c['id']}", "name", loc, c['name'], c_names[loc]))
            if loc in c_descs:
                all_tasks.append((f"COLL:{c['id']}", "description", loc, c['description'], c_descs[loc]))

    # 3. Card tasks
    for card in cards:
        c_ans = json.loads(card['answers'] or '{}')
        c_prm = json.loads(card['prompts'] or '{}')
        c_dsp = json.loads(card['display_texts'] or '{}')
        for loc in locales:
            if loc in c_ans:
                all_tasks.append((card['id'], "answer", loc, card['answer'], c_ans[loc]))
            if loc in c_prm:
                all_tasks.append((card['id'], "prompt", loc, card['prompt'], c_prm[loc]))
            if loc in c_dsp:
                all_tasks.append((card['id'], "display_text", loc, card['display_text'], c_dsp[loc]))

    print(f"Auditing metadata and {len(cards)} cards across {len(locales)} languages...")
    print(f"Total tasks: {len(all_tasks)}")

    def check_translation(item_id, field, locale, global_text, current_text):
        if not global_text or not global_text.strip() or not current_text:
            return None
        try:
            time.sleep(0.02)
            # Basic digit scripts don't translate well via Google if it's just numbers
            # but descriptions and prompts will.
            translated = GoogleTranslator(source='en', target=locale).translate(global_text)
            if not translated: return None
            
            if normalize(current_text) != normalize(translated):
                return {
                    "item_id": item_id,
                    "field": field,
                    "locale": locale,
                    "global_text": global_text,
                    "current_text": current_text,
                    "translated_text": translated,
                    "status": "mismatch"
                }
        except:
            pass
        return None

    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = [executor.submit(check_translation, *task) for task in all_tasks]
        count = 0
        for future in as_completed(futures):
            res = future.result()
            if res:
                diffs.append(res)
            count += 1
            if count % 100 == 0:
                print(f"  Progress: {count}/{len(all_tasks)} checks done.")

    output_path = "scripts/.tmp/add_subtract_quality_report.csv"
    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["item_id", "field", "locale", "global_text", "current_text", "translated_text", "status"])
        writer.writeheader()
        writer.writerows(diffs)
    
    print(f"\nDone! Quality report saved to {output_path}")
    print(f"Total differences found: {len(diffs)}")

if __name__ == "__main__":
    main()
