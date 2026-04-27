import json
import subprocess
import csv
import unicodedata
import time
from deep_translator import GoogleTranslator
from concurrent.futures import ThreadPoolExecutor, as_completed

DB_NAME = "aliolo-db"
SUBJECT_ID = "424bd963-b3d7-4f5b-b021-56ec5492d1a6"

def run_wrangler(sql):
    cmd = ["npx", "wrangler", "d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        return []
    return json.loads(res.stdout)[0]["results"]

def normalize(text):
    if not text: return ""
    text = "".join(ch for ch in text if not unicodedata.category(ch).startswith('P'))
    return unicodedata.normalize("NFC", text).strip().lower()

def main():
    print("Fetching all cards for Car Body Styles subject...")
    cards = run_wrangler(f"SELECT id, subject_id, answer, answers, prompt, prompts, display_text, display_texts FROM cards WHERE subject_id = '{SUBJECT_ID}'")
    
    if not cards:
        print("No cards found.")
        return

    subj_data = run_wrangler(f"SELECT name, names FROM subjects WHERE id = '{SUBJECT_ID}'")
    subject_name = subj_data[0]['name'] if subj_data else "Unknown"
    subject_names = json.loads(subj_data[0]['names'] or '{}') if subj_data else {}

    diffs = []
    locales = ['ar', 'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'fi', 'fr', 'ga', 'hi', 'hr', 'hu', 'id', 'it', 'ja', 'ko', 'lt', 'lv', 'mt', 'nl', 'pl', 'pt', 'ro', 'sk', 'sl', 'sv', 'tl', 'tr', 'uk', 'vi', 'zh']
    
    print(f"Auditing {len(cards)} cards across {len(locales)} languages for 4 fields...")

    def check_translation(card_id, field, locale, global_text, current_text):
        if not global_text or not global_text.strip() or not current_text:
            return None
        
        try:
            time.sleep(0.05) 
            translated = GoogleTranslator(source='en', target=locale).translate(global_text)
            if not translated: return None
            
            if normalize(current_text) != normalize(translated):
                return {
                    "card_id": card_id,
                    "field": field,
                    "locale": locale,
                    "global_text": global_text,
                    "current_text": current_text,
                    "translated_text": translated,
                    "status": "mismatch"
                }
        except Exception:
            pass
        return None

    all_tasks = []
    for locale in locales:
        cur_name = subject_names.get(locale)
        if cur_name:
            all_tasks.append(("SUBJECT", "subject_name", locale, subject_name, cur_name))

    for card in cards:
        for f_base, f_map in [("answer", "answers"), ("prompt", "prompts"), ("display_text", "display_texts")]:
            global_val = card.get(f_base) or ""
            try:
                local_map = json.loads(card.get(f_map) or '{}')
            except:
                continue
            
            for locale in locales:
                cur_val = local_map.get(locale)
                if cur_val:
                    all_tasks.append((card['id'], f_base, locale, global_val, cur_val))

    print(f"Starting {len(all_tasks)} translation checks...")
    
    with ThreadPoolExecutor(max_workers=5) as executor:
        futures = [executor.submit(check_translation, *task) for task in all_tasks]
        
        count = 0
        for future in as_completed(futures):
            res = future.result()
            if res:
                diffs.append(res)
            count += 1
            if count % 200 == 0:
                print(f"  Progress: {count}/{len(all_tasks)} checks done. Found {len(diffs)} mismatches.")

    output_path = "aliolo/scripts/.tmp/car_body_styles_quality_report.csv"
    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["card_id", "field", "locale", "global_text", "current_text", "translated_text", "status"])
        writer.writeheader()
        writer.writerows(diffs)
    
    print(f"\nDone! Checked Car Body Styles subject.")
    print(f"Total differences found: {len(diffs)}")
    print(f"Report saved to {output_path}")

if __name__ == "__main__":
    main()
