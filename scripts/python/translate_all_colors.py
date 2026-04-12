import requests
import json
import re
import time

url_base = "https://mltdjjszycfmokwqsqxm.supabase.co"
apikey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
headers = {
    "apikey": apikey,
    "Authorization": f"Bearer {apikey}",
    "Content-Type": "application/json",
    "Prefer": "return=minimal"
}

subject_id = "0b84447d-3af3-4509-bdf6-c4e7fe822cc7"
langs = ['ar', 'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'fi', 'fr', 'ga', 'hi', 'hr', 'hu', 'id', 'it', 'ja', 'ko', 'lt', 'lv', 'mt', 'nl', 'pl', 'pt', 'ro', 'sk', 'sl', 'sv', 'tl', 'tr', 'uk', 'vi', 'zh']
USER_AGENT = "AlioloBot/1.0 (https://aliolo.com; hello@aliolo.com)"

def get_wikipedia_translations(term):
    # Try to find the best Wikipedia page for the color
    wiki_url = "https://en.wikipedia.org/w/api.php"
    
    # Use " (color)" suffix to prioritize color pages
    search_term = f"{term} (color)"
    s_params = { "action": "query", "list": "search", "srsearch": search_term, "format": "json" }
    
    try:
        s_resp = requests.get(wiki_url, params=s_params, headers={"User-Agent": USER_AGENT}).json()
        results = s_resp.get("query", {}).get("search", [])
        
        if not results:
            # Try without suffix
            s_params["srsearch"] = term
            s_resp = requests.get(wiki_url, params=s_params, headers={"User-Agent": USER_AGENT}).json()
            results = s_resp.get("query", {}).get("search", [])
            
        if not results:
            return None
            
        title = results[0]['title']
        
        # Get langlinks
        l_params = { "action": "query", "prop": "langlinks", "titles": title, "lllimit": 500, "format": "json" }
        l_resp = requests.get(wiki_url, params=l_params, headers={"User-Agent": USER_AGENT}).json()
        pages = l_resp.get("query", {}).get("pages", {})
        
        translations = { 'en': term }
        for pid in pages:
            if int(pid) < 0: continue
            links = pages[pid].get("langlinks", [])
            for link in links:
                lang = link.get("lang")
                val = link.get("*")
                # Clean up translation (remove parentheticals like "(color)")
                val = re.sub(r'\s*\(.*?\)', '', val).strip()
                if lang in langs:
                    translations[lang] = val
                elif lang == 'fil' and 'tl' in langs:
                    translations['tl'] = val
                elif lang == 'zh-hans' and 'zh' in langs:
                    translations['zh'] = val
        return translations
    except Exception as e:
        print(f"Wiki error for {term}: {e}")
        return None

def translate_all_cards():
    # 1. Fetch all cards
    resp = requests.get(f"{url_base}/rest/v1/cards?subject_id=eq.{subject_id}&select=id,localized_data", headers=headers)
    if resp.status_code != 200:
        print(f"Failed to fetch cards: {resp.text}")
        return
    
    cards = resp.json()
    print(f"Processing {len(cards)} cards...")
    
    for i, card in enumerate(cards):
        loc_data = card.get('localized_data', {})
        global_ans = loc_data.get('global', {}).get('answer', '')
        
        parts = global_ans.split(', ')
        if len(parts) < 2: continue
        
        en_name = parts[0]
        hex_code = parts[1]
        
        # Check if we need translations (if many langs are identical to English)
        identical_count = 0
        for l in langs:
            if l == 'en': continue
            if loc_data.get(l, {}).get('answer', '').startswith(en_name):
                identical_count += 1
        
        if identical_count > 10: # Threshold to decide if it needs translation
            print(f"[{i+1}/{len(cards)}] Translating {en_name}...")
            translations = get_wikipedia_translations(en_name)
            
            if translations:
                for lang in langs:
                    t_name = translations.get(lang, en_name)
                    loc_data[lang] = {
                        "answer": f"{t_name}, {hex_code}",
                        "prompt": "",
                        "audio_url": None
                    }
                # Update global too
                loc_data["global"]["answer"] = f"{en_name}, {hex_code}"
                
                # Push update
                card_id = card['id']
                up_resp = requests.patch(f"{url_base}/rest/v1/cards?id=eq.{card_id}", headers=headers, json={"localized_data": loc_data})
                if up_resp.status_code >= 400:
                    print(f"Failed to update {card_id}: {up_resp.text}")
                else:
                    print(f"Updated {en_name}")
            else:
                print(f"No translations found for {en_name}")
            
            # Rate limiting for Wiki
            time.sleep(0.2)
        else:
            print(f"[{i+1}/{len(cards)}] {en_name} seems already translated.")

if __name__ == "__main__":
    translate_all_cards()
