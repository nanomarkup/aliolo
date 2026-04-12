import requests
import json
import re

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

def split_camel_case(text):
    # Split "AliceBlue" into "Alice Blue"
    # Also handles "DarkGoldenRod" into "Dark Golden Rod"
    return re.sub(r'([a-z])([A-Z])', r'\1 \2', text)

def get_wikipedia_translations(term):
    wiki_url = "https://en.wikipedia.org/w/api.php"
    # Search
    s_params = { "action": "query", "list": "search", "srsearch": term, "format": "json" }
    try:
        s_resp = requests.get(wiki_url, params=s_params, headers={"User-Agent": USER_AGENT}).json()
        results = s_resp.get("query", {}).get("search", [])
        if not results: return { 'en': term }
        title = results[0]['title']
        
        # Get langlinks
        l_params = { "action": "query", "prop": "langlinks", "titles": title, "lllimit": 500, "format": "json" }
        l_resp = requests.get(wiki_url, params=l_params, headers={"User-Agent": USER_AGENT}).json()
        pages = l_resp.get("query", {}).get("pages", {})
        translations = { 'en': title }
        for pid in pages:
            if int(pid) < 0: continue
            links = pages[pid].get("langlinks", [])
            for link in langlinks:
                lang = link.get("lang")
                val = link.get("*")
                if lang in langs:
                    translations[lang] = val
        return translations
    except:
        return { 'en': term }

def update_colors():
    # 1. Fetch all cards
    resp = requests.get(f"{url_base}/rest/v1/cards?subject_id=eq.{subject_id}&select=id,localized_data", headers=headers)
    if resp.status_code != 200:
        print(f"Failed to fetch cards: {resp.text}")
        return
    
    cards = resp.json()
    print(f"Checking {len(cards)} cards...")
    
    for card in cards:
        loc_data = card.get('localized_data', {})
        global_ans = loc_data.get('global', {}).get('answer', '')
        
        # Extract name and hex
        # Format: "AliceBlue, #F0F8FF"
        parts = global_ans.split(', ')
        if len(parts) < 2: continue
        
        original_name = parts[0]
        hex_code = parts[1]
        
        split_name = split_camel_case(original_name)
        
        if split_name != original_name:
            print(f"Updating '{original_name}' -> '{split_name}'")
            
            # Re-fetch translations for the split name
            # Actually, to be safer and faster, we can just split the existing English translation 
            # or try Wikipedia if it's a significant change.
            # But let's use Wikipedia to get proper multi-word translations.
            translations = get_wikipedia_translations(split_name)
            
            # Update all languages
            for lang in langs:
                # If we have a translation from Wikipedia, use it. 
                # Otherwise, use the split version of the English name as a fallback.
                t_name = translations.get(lang, split_name)
                # Ensure the naming convention "Name, #HEXCODE"
                loc_data[lang] = {
                    "answer": f"{t_name}, {hex_code}",
                    "prompt": "",
                    "audio_url": None
                }
            
            # Update global too
            loc_data["global"] = {
                "answer": f"{split_name}, {hex_code}",
                "prompt": "",
                "audio_url": None,
                "video_url": "",
                "image_urls": []
            }
            
            # Push update
            card_id = card['id']
            up_resp = requests.patch(f"{url_base}/rest/v1/cards?id=eq.{card_id}", headers=headers, json={"localized_data": loc_data})
            if up_resp.status_code >= 400:
                print(f"Failed to update {card_id}: {up_resp.text}")
            else:
                print(f"Successfully updated {split_name}")

if __name__ == "__main__":
    update_colors()
