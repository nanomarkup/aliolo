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

def update_card_names():
    # 1. Fetch all cards
    resp = requests.get(f"{url_base}/rest/v1/cards?subject_id=eq.{subject_id}&select=id,localized_data", headers=headers)
    if resp.status_code != 200:
        print(f"Failed to fetch cards: {resp.text}")
        return
    
    cards = resp.json()
    print(f"Found {len(cards)} cards to update.")
    
    for card in cards:
        loc_data = card.get('localized_data', {})
        
        # We need to find the hex code. It's currently in "Name (#HEX)"
        # We'll search in 'en' or 'global' to find it reliably.
        en_ans = loc_data.get('en', {}).get('answer', '')
        match = re.search(r'\(#([0-9a-fA-F]{6})\)', en_ans)
        if not match:
            # Try global
            global_ans = loc_data.get('global', {}).get('answer', '')
            match = re.search(r'\(#([0-9a-fA-F]{6})\)', global_ans)
            
        if match:
            hex_code = f"#{match.group(1)}"
            
            # Update all languages
            for lang in loc_data:
                ans = loc_data[lang].get('answer', '')
                # Replace " ( #HEX )" or "(#HEX)" with ", #HEX"
                new_ans = re.sub(r'\s*\(\s*#[0-9a-fA-F]{6}\s*\)', f", {hex_code}", ans)
                loc_data[lang]['answer'] = new_ans
            
            # Update card in database
            card_id = card['id']
            up_resp = requests.patch(f"{url_base}/rest/v1/cards?id=eq.{card_id}", 
                                   headers=headers, 
                                   json={"localized_data": loc_data})
            if up_resp.status_code >= 400:
                print(f"Failed to update card {card_id}: {up_resp.text}")
            else:
                print(f"Updated card {card_id}")
        else:
            print(f"Could not find hex for card {card['id']}: {en_ans}")

if __name__ == "__main__":
    update_card_names()
