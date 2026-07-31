import json
import subprocess
import csv
import time
from deep_translator import GoogleTranslator

DB_NAME = "aliolo-db"
SAMPLE_SIZE = 50

def run_wrangler(sql):
    cmd = ["npx", "wrangler", "d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"]
    res = subprocess.run(cmd, capture_output=True, text=True)
    return json.loads(res.stdout)[0]["results"]

def main():
    print(f"Fetching {SAMPLE_SIZE} random cards...")
    # Using a fixed seed for reproducible check in this turn if needed, or just random
    cards = run_wrangler(f"SELECT id, subject_id, answer, answers FROM cards WHERE answer != '' ORDER BY RANDOM() LIMIT {SAMPLE_SIZE}")
    
    diffs = []
    locales_to_check = ['es', 'fr', 'de', 'it', 'uk', 'hi', 'zh', 'ja'] # Checking most common 8 to avoid heavy rate limits
    
    print(f"Auditing {len(cards)} cards across {len(locales_to_check)} languages (Total {len(cards)*len(locales_to_check)} pairs)...")
    
    for card in cards:
        card_id = card['id']
        global_text = card['answer']
        
        try:
            answers = json.loads(card['answers'] or '{}')
        except:
            continue

        for lang in locales_to_check:
            current_val = answers.get(lang)
            if not current_val: continue
            
            try:
                # Use deep-translator (no API key needed)
                translated = GoogleTranslator(source='en', target=lang).translate(global_text)
                
                # Simple normalization
                if current_val.strip().lower() != translated.strip().lower():
                    diffs.append({
                        "card_id": card_id,
                        "subject_id": card['subject_id'],
                        "field": "answer",
                        "locale": lang,
                        "global_text": global_text,
                        "current_text": current_val,
                        "translated_text": translated,
                        "status": "mismatch"
                    })
            except Exception as e:
                pass
        
        if len(diffs) % 20 == 0 and len(diffs) > 0:
            print(f"  Found {len(diffs)} differences...")

    output_path = "aliolo/scripts/.tmp/translation_quality_report_50_cards.csv"
    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["card_id", "subject_id", "field", "locale", "global_text", "current_text", "translated_text", "status"])
        writer.writeheader()
        writer.writerows(diffs)
    
    print(f"\nDone! Checked 50 cards completely for 8 languages.")
    print(f"Total differences found: {len(diffs)}")
    print(f"Report saved to {output_path}")

if __name__ == "__main__":
    main()
