import requests
import urllib.parse
import json
import time
import sys

URL = "https://mltdjjszycfmokwqsqxm.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
headers = {"apikey": KEY, "Authorization": "Bearer " + KEY, "Content-Type": "application/json"}

LANGS = ['ar', 'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'fi', 'fr', 'ga', 'hi', 'hr', 'hu', 'id', 'it', 'ja', 'ko', 'lt', 'lv', 'mt', 'nl', 'pl', 'pt', 'ro', 'sk', 'sl', 'sv', 'tl', 'tr', 'uk', 'vi', 'zh']

with open('cards_to_translate.json') as f:
    cards = json.load(f)

trans_cache = {}

def translate_text(text, target_lang):
    if not text: return ""
    if target_lang == 'en': return text
    if target_lang == 'zh': target_lang = 'zh-CN'
    
    cache_key = f"{text}_{target_lang}"
    if cache_key in trans_cache:
        return trans_cache[cache_key]
        
    url = f"https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl={target_lang}&dt=t&q={urllib.parse.quote(text)}"
    try:
        r = requests.get(url, timeout=10)
        if r.status_code == 200:
            res = r.json()
            translated = ''.join([item[0] for item in res[0]])
            trans_cache[cache_key] = translated
            return translated
        else:
            time.sleep(1)
            # Retry once
            r = requests.get(url, timeout=10)
            if r.status_code == 200:
                res = r.json()
                translated = ''.join([item[0] for item in res[0]])
                trans_cache[cache_key] = translated
                return translated
            return text
    except Exception as e:
        print(f"Error translating '{text}': {e}")
        time.sleep(1)
        return text

# Start from index 10 since batch 1 was manually updated
print(f"Starting background translation for {len(cards) - 10} cards...")
sys.stdout.flush()

success = 0
# Continuing from card 11 (index 10)
for i in range(10, len(cards)):
    card = cards[i]
    card_id = card['id']
    prompt = card.get('prompt') or ''
    answer = card.get('answer') or ''
    prompt = prompt.strip()
    answer = answer.strip()
    
    res = requests.get(f"{URL}/rest/v1/cards?id=eq.{card_id}&select=localized_data", headers=headers)
    if res.status_code != 200: 
        continue
        
    loc = res.json()[0]['localized_data']
    needs_patch = False
    
    for l in LANGS:
        if l not in loc:
            loc[l] = {}
        
        c_prompt = loc[l].get('prompt', '').strip()
        c_answer = loc[l].get('answer', '').strip()
        
        t_prompt = translate_text(prompt, l) if prompt else ""
        t_answer = translate_text(answer, l) if answer else ""
        
        if c_prompt != t_prompt or c_answer != t_answer:
            loc[l]['prompt'] = t_prompt
            loc[l]['answer'] = t_answer
            needs_patch = True
            
    if needs_patch:
        patch = requests.patch(f"{URL}/rest/v1/cards?id=eq.{card_id}", headers=headers, json={'localized_data': loc})
        if patch.status_code in (200, 204):
            success += 1
            
    if (i + 1) % 10 == 0:
        print(f"Progress: {i + 1}/{len(cards)} cards updated. Translations cached: {len(trans_cache)}")
        sys.stdout.flush()

print(f"Finished! Successfully translated and updated {success} remaining cards.")
