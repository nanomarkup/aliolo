import sys
import requests
import json
import urllib.parse
import time

URL = "https://mltdjjszycfmokwqsqxm.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
headers = {"apikey": KEY, "Authorization": "Bearer " + KEY, "Content-Type": "application/json"}

LANGS = ['ar', 'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'fi', 'fr', 'ga', 'hi', 'hr', 'hu', 'id', 'it', 'ja', 'ko', 'lt', 'lv', 'mt', 'nl', 'pl', 'pt', 'ro', 'sk', 'sl', 'sv', 'tl', 'tr', 'uk', 'vi', 'zh']

def translate_text(text, target_lang):
    if not text: return ""
    if target_lang == 'en': return text
    if target_lang == 'zh': target_lang = 'zh-CN'
    
    url = f"https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl={target_lang}&dt=t&q={urllib.parse.quote(text)}"
    try:
        r = requests.get(url, timeout=10)
        if r.status_code == 200:
            res = r.json()
            translated = ''.join([item[0] for item in res[0]])
            return translated
        else:
            time.sleep(1)
            r = requests.get(url, timeout=10)
            if r.status_code == 200:
                res = r.json()
                translated = ''.join([item[0] for item in res[0]])
                return translated
            print(f"  [!] HTTP {r.status_code} translating '{text}' to {target_lang}. Retaining original text.")
            return text 
    except Exception as e:
        print(f"  [!] Error translating '{text}' to {target_lang}: {e}. Retaining original text.")
        return text

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 translate_single_card.py <card_id>")
        sys.exit(1)
        
    card_id = sys.argv[1].strip()
    
    print(f"Fetching card {card_id}...")
    res = requests.get(f"{URL}/rest/v1/cards?id=eq.{card_id}&select=id,localized_data", headers=headers)
    
    if res.status_code != 200:
        print(f"Failed to fetch card. Error: {res.text}")
        sys.exit(1)
        
    cards = res.json()
    if not cards:
        print(f"Card with ID {card_id} not found.")
        sys.exit(1)
        
    card = cards[0]
    localized = card.get("localized_data", {}) or {}
    global_data = localized.get("global", {})
    
    answer_en = global_data.get("answer", "").strip()
    prompt_en = global_data.get("prompt", "").strip()
    
    new_localized = {
        "global": global_data
    }
    
    print(f"Translating answer: '{answer_en}' and prompt: '{prompt_en}'...")
    
    for lang in LANGS:
        new_localized[lang] = {}
        
        if answer_en:
            print(f"  -> Translating answer to {lang}...")
            new_localized[lang]["answer"] = translate_text(answer_en, lang)
            time.sleep(0.3)
        else:
            new_localized[lang]["answer"] = ""
            
        if prompt_en:
            print(f"  -> Translating prompt to {lang}...")
            new_localized[lang]["prompt"] = translate_text(prompt_en, lang)
            time.sleep(0.3)
            
    # Re-serialize to JSON and escape single quotes for SQL
    json_str = json.dumps(new_localized, indent=2, ensure_ascii=False).replace("'", "''")
    sql = f"UPDATE cards\nSET localized_data = '{json_str}'::jsonb\nWHERE id = '{card_id}';\n"
    
    out_filename = f"update_card_{card_id}_translated.sql"
    with open(out_filename, "w", encoding="utf-8") as f:
        f.write(sql)
        
    print(f"\nDone! Translated SQL saved to {out_filename}")

if __name__ == "__main__":
    main()