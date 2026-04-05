import requests
import json

SUPABASE_URL = "https://mltdjjszycfmokwqsqxm.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
SUBJECT_ID = "6e242fd7-a743-49d5-813e-31f5e9622470"

# Heuristic ranking for International Organizations
PROMINENCE_LEVELS = {
    1: ["United Nations", "European Union", "NATO", "FIFA", "International Olympic Committee", "UNESCO", "World Trade Organization"],
    2: ["Arab League", "African Union", "ASEAN", "Commonwealth of Nations", "International Criminal Court", "G7", "G20", "BRICS", "Mercosur"],
    3: ["OPEC", "Red Cross", "Council of Europe", "Nordic Council", "Commonwealth of Independent States", "CARICOM"],
    4: ["OECD", "European Free Trade Association", "Interpol", "World Health Organization", "International Atomic Energy Agency"],
    5: ["Eurasian Economic Union", "Gulf Cooperation Council", "Organization of American States", "East African Community"],
    # ... others fall through
}

def get_level(name):
    for lv, orgs in PROMINENCE_LEVELS.items():
        if any(o.lower() in name.lower() for o in orgs):
            return lv
    
    # Heuristics for the rest
    if "Sport" in name or "Games" in name or "Olympic" in name:
        return 8
    if "Economic" in name or "Trade" in name or "Trade" in name:
        return 10
    if "Central" in name or "South" in name or "East" in name or "West" in name:
        return 12
    if "Commission" in name or "Parliament" in name or "Union" in name:
        return 14
    
    return 15

def update_levels():
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json"
    }
    
    url = f"{SUPABASE_URL}/rest/v1/cards?subject_id=eq.{SUBJECT_ID}&select=id,localized_data"
    response = requests.get(url, headers=headers)
    cards = response.json()
    
    print(f"Updating {len(cards)} cards...")
    
    for card in cards:
        card_id = card['id']
        name = card['localized_data'].get('global', {}).get('answer', 'Unknown')
        
        level = get_level(name)
        
        # Add some distribution based on name length or just spreading
        if level >= 15:
            level = 15 + (len(name) % 6) # Spread 15-20
            
        print(f"Card {card_id}: {name} -> Level {level}")
        
        update_url = f"{SUPABASE_URL}/rest/v1/cards?id=eq.{card_id}"
        requests.patch(update_url, headers=headers, json={"level": level})

if __name__ == "__main__":
    update_levels()
