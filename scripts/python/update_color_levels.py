import requests
import json

url_base = "https://mltdjjszycfmokwqsqxm.supabase.co"
apikey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
headers = {
    "apikey": apikey,
    "Authorization": f"Bearer {apikey}",
    "Content-Type": "application/json",
    "Prefer": "return=minimal"
}

subject_id = "0b84447d-3af3-4509-bdf6-c4e7fe822cc7"

# Rough ranking of 148 HTML colors by familiarity (1 = most common, 20 = least)
tier_map = {
    "Red": 1, "Blue": 1, "Green": 1, "Yellow": 1, "Black": 1, "White": 1, "Orange": 1,
    "Purple": 2, "Pink": 2, "Brown": 2, "Gray": 2, "Grey": 2, "Cyan": 2, "Magenta": 2,
    "Lime": 3, "Olive": 3, "Maroon": 3, "Navy": 3, "Teal": 3, "Silver": 3, "Gold": 3,
    "Violet": 4, "Indigo": 4, "Coral": 4, "Salmon": 4, "Khaki": 4, "Plum": 4, "Orchid": 4,
    "Azure": 5, "Beige": 5, "Ivory": 5, "Turquoise": 5, "Crimson": 5, "Tomato": 5, "Sienna": 5,
    "Peru": 6, "Chocolate": 6, "Tan": 6, "Thistle": 6, "Snow": 6, "Aqua": 6, "Fuchsia": 6,
    "Wheat": 7, "Linen": 7, "Lavender": 7, "Bisque": 7, "Moccasin": 7, "Cornsilk": 7, "Sea Shell": 7,
    "Honey Dew": 8, "Mint Cream": 8, "Floral White": 8, "Ghost White": 8, "Antique White": 8, "Old Lace": 8, "Papaya Whip": 8,
    "Blanched Almond": 9, "Lemon Chiffon": 9, "Light Yellow": 9, "Light Cyan": 9, "Light Green": 9, "Light Blue": 9, "Light Pink": 9,
    "Light Coral": 10, "Light Salmon": 10, "Light Sea Green": 10, "Light Sky Blue": 10, "Light Gray": 10, "Light Grey": 10, "Light Slate Gray": 10,
    "Light Slate Grey": 11, "Light Steel Blue": 11, "Dark Red": 11, "Dark Blue": 11, "Dark Green": 11, "Dark Orange": 11, "Dark Cyan": 11,
    "Dark Magenta": 12, "Dark Violet": 12, "Dark Orchid": 12, "Dark Salmon": 12, "Dark Sea Green": 12, "Dark Slate Blue": 12, "Dark Slate Gray": 12,
    "Dark Slate Grey": 13, "Dark Turquoise": 13, "Dark Khaki": 13, "Dark Golden Rod": 13, "Dark Olive Green": 13, "Deep Pink": 13, "Deep Sky Blue": 13,
    "Dim Gray": 14, "Dim Grey": 14, "Medium Blue": 14, "Medium Purple": 14, "Medium Orchid": 14, "Medium Sea Green": 14, "Medium Slate Blue": 14,
    "Medium Spring Green": 15, "Medium Turquoise": 15, "Medium Violet Red": 15, "Medium Aqua Marine": 15, "Pale Green": 15, "Pale Turquoise": 15, "Pale Violet Red": 15,
    "Pale Golden Rod": 16, "Slate Blue": 16, "Slate Gray": 16, "Slate Grey": 16, "Sky Blue": 16, "Royal Blue": 16, "Steel Blue": 16,
    "Dodger Blue": 17, "Cornflower Blue": 17, "Cadet Blue": 17, "Powder Blue": 17, "Alice Blue": 17, "Midnight Blue": 17, "Navajo White": 17,
    "Peach Puff": 18, "Rosy Brown": 18, "Saddle Brown": 18, "Sandy Brown": 18, "Fire Brick": 18, "Indian Red": 18, "Hot Pink": 18,
    "Yellow Green": 19, "Green Yellow": 19, "Lawn Green": 19, "Spring Green": 19, "Forest Green": 19, "Lime Green": 19, "Sea Green": 19,
    "Chartreuse": 20, "Burly Wood": 20, "Gainsboro": 20, "Lavender Blush": 20, "Misty Rose": 20, "Rebecca Purple": 20, "Light Golden Rod Yellow": 20
}

def get_level(name):
    # Try exact match
    if name in tier_map:
        return tier_map[name]
    
    # Fallbacks based on word length and content if not mapped
    words = name.split()
    if len(words) == 1:
        return 7
    elif len(words) == 2:
        if "Dark" in words or "Light" in words:
            return 11
        if "Medium" in words or "Pale" in words:
            return 15
        return 18
    else:
        return 20

def update_color_levels():
    resp = requests.get(f"{url_base}/rest/v1/cards?subject_id=eq.{subject_id}&select=id,level,localized_data", headers=headers)
    if resp.status_code != 200:
        print(f"Failed to fetch cards: {resp.text}")
        return
    
    cards = resp.json()
    print(f"Found {len(cards)} cards to check.")
    
    updates = 0
    for card in cards:
        loc_data = card.get('localized_data', {})
        global_ans = loc_data.get('global', {}).get('answer', '')
        
        parts = global_ans.split(', ')
        if len(parts) < 2: continue
        
        name = parts[0]
        current_level = card.get('level')
        
        new_level = get_level(name)
        
        if new_level != current_level:
            card_id = card['id']
            up_resp = requests.patch(f"{url_base}/rest/v1/cards?id=eq.{card_id}", 
                                   headers=headers, 
                                   json={"level": new_level})
            if up_resp.status_code >= 400:
                print(f"Failed to update {name}: {up_resp.text}")
            else:
                print(f"Updated '{name}' from level {current_level} to {new_level}")
                updates += 1
                
    print(f"Completed. Updated {updates} cards.")

if __name__ == "__main__":
    update_color_levels()
