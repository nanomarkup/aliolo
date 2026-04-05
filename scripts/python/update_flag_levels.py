import requests
import json

SUPABASE_URL = "https://mltdjjszycfmokwqsqxm.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
SUBJECT_ID = "35b2f5c1-10be-4c1d-b915-1159ef35fe26"

# A heuristic ranking of countries by prominence/familiarity
# Level 1 (Most prominent) -> Level 20 (Least prominent)
PROMINENCE_LEVELS = {
    # Level 1: G7 + China + Russia + Major Global Players
    1: ["United States", "United Kingdom", "France", "Germany", "Japan", "China", "Canada", "Italy", "Russia", "Australia", "Brazil", "India", "South Korea", "Spain"],
    # Level 2: G20 members and large European nations
    2: ["Mexico", "Indonesia", "Turkey", "Saudi Arabia", "South Africa", "Argentina", "Netherlands", "Switzerland", "Sweden", "Poland", "Belgium", "Norway", "Portugal"],
    # Level 3: Regional leaders and common familiarity
    3: ["Egypt", "Thailand", "Vietnam", "Israel", "Ukraine", "Greece", "Austria", "Denmark", "Finland", "Singapore", "New Zealand", "Ireland", "Colombia", "Pakistan", "Nigeria"],
    # Level 4: Central/South America and Southeast Asia
    4: ["Chile", "Peru", "Philippines", "Malaysia", "Iran", "Iraq", "Morocco", "Algeria", "Kenya", "Ethiopia", "Romania", "Czech Republic", "Hungary", "United Arab Emirates", "Cuba"],
    # ... and so on. We'll handle the rest by a falling-through logic.
}

def get_level(name):
    for lv, countries in PROMINENCE_LEVELS.items():
        if name in countries:
            return lv
    # Heuristic for the rest based on name length or just spreading them out
    # If not in top 4 levels, distribute between 5-20
    # We can use a simple hash to keep it consistent but random-ish for now
    # or just group them broadly.
    # Let's do some broad regional/known groupings
    if any(c in name for c in ["island", "saint", "st.", "state", "republic", "territory"]):
        return 15
    return 8

def update_levels():
    # 1. Fetch all cards for the subject
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json"
    }
    
    url = f"{SUPABASE_URL}/rest/v1/cards?subject_id=eq.{SUBJECT_ID}&select=id,localized_data"
    response = requests.get(url, headers=headers)
    cards = response.json()
    
    print(f"Found {len(cards)} cards. Updating levels...")
    
    for card in cards:
        card_id = card['id']
        # Extract country name from English answer
        name_en = card['localized_data'].get('en', {}).get('answer', 'Unknown')
        # Clean name (remove "flag of ")
        country_name = name_en.replace("flag of ", "").replace("Flag of ", "").split(";")[0].strip()
        
        level = get_level(country_name)
        
        # Further refine: if not in levels 1-4, let's spread them based on country importance
        # This is a mock spreading. In a real app we might use population or GDP.
        # Since I can't easily fetch GDP for 199 countries here, I'll use a more granular logic.
        
        # Level 5-7: Known European/Asian/LatAm countries not in 1-4
        if level == 8 and country_name in ["Bulgaria", "Slovakia", "Slovenia", "Croatia", "Serbia", "Bulgaria", "Estonia", "Lithuania", "Latvia", "Iceland", "Luxembourg"]:
            level = 5
        elif level == 8 and country_name in ["Panama", "Costa Rica", "Uruguay", "Dominican Republic", "Jordan", "Qatar", "Kuwait", "Lebanon"]:
            level = 6
        elif level == 8 and country_name in ["Kazakhstan", "Azerbaijan", "Georgia", "Armenia", "Uzbekistan", "Monaco", "Malta", "Cyprus"]:
            level = 7
        elif level == 8 and country_name in ["Ghana", "Angola", "Tanzania", "Sri Lanka", "Bangladesh", "Myanmar", "North Korea"]:
            level = 9
        elif level == 15: # Microstates / Islands
            if country_name in ["Saint Kitts and Nevis", "Saint Lucia", "Saint Vincent and the Grenadines", "Antigua and Barbuda"]:
                level = 18
            elif country_name in ["Kiribati", "Tuvalu", "Nauru", "Marshall Islands", "Palau", "Micronesia"]:
                level = 20
            else:
                level = 17
        elif level == 8:
            # Spread the rest between 10-14
            level = 10 + (len(country_name) % 5)
            
        print(f"Card {card_id}: {country_name} -> Level {level}")
        
        # 2. Update level in DB
        update_url = f"{SUPABASE_URL}/rest/v1/cards?id=eq.{card_id}"
        requests.patch(update_url, headers=headers, json={"level": level})

if __name__ == "__main__":
    update_levels()
