import requests
import json
import uuid
import os
import re

url_base = "https://mltdjjszycfmokwqsqxm.supabase.co"
apikey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
headers = {
    "apikey": apikey,
    "Authorization": f"Bearer {apikey}"
}

subject_id = "0b84447d-3af3-4509-bdf6-c4e7fe822cc7"
owner_id = "f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac"

langs = ['ar', 'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'fi', 'fr', 'ga', 'hi', 'hr', 'hu', 'id', 'it', 'ja', 'ko', 'lt', 'lv', 'mt', 'nl', 'pl', 'pt', 'ro', 'sk', 'sl', 'sv', 'tl', 'tr', 'uk', 'vi', 'zh']

USER_AGENT = "AlioloBot/1.0 (https://aliolo.com; hello@aliolo.com)"

colors = [
  { "name": "AliceBlue", "hex": "#F0F8FF" },
  { "name": "AntiqueWhite", "hex": "#FAEBD7" },
  { "name": "Aqua", "hex": "#00FFFF" },
  { "name": "Aquamarine", "hex": "#7FFFD4" },
  { "name": "Azure", "hex": "#F0FFFF" },
  { "name": "Beige", "hex": "#F5F5DC" },
  { "name": "Bisque", "hex": "#FFE4C4" },
  { "name": "Black", "hex": "#000000" },
  { "name": "BlanchedAlmond", "hex": "#FFEBCD" },
  { "name": "Blue", "hex": "#0000FF" },
  { "name": "BlueViolet", "hex": "#8A2BE2" },
  { "name": "Brown", "hex": "#A52A2A" },
  { "name": "BurlyWood", "hex": "#DEB887" },
  { "name": "CadetBlue", "hex": "#5F9EA0" },
  { "name": "Chartreuse", "hex": "#7FFF00" },
  { "name": "Chocolate", "hex": "#D2691E" },
  { "name": "Coral", "hex": "#FF7F50" },
  { "name": "CornflowerBlue", "hex": "#6495ED" },
  { "name": "Cornsilk", "hex": "#FFF8DC" },
  { "name": "Crimson", "hex": "#DC143C" },
  { "name": "Cyan", "hex": "#00FFFF" },
  { "name": "DarkBlue", "hex": "#00008B" },
  { "name": "DarkCyan", "hex": "#008B8B" },
  { "name": "DarkGoldenRod", "hex": "#B8860B" },
  { "name": "DarkGray", "hex": "#A9A9A9" },
  { "name": "DarkGrey", "hex": "#A9A9A9" },
  { "name": "DarkGreen", "hex": "#006400" },
  { "name": "DarkKhaki", "hex": "#BDB76B" },
  { "name": "DarkMagenta", "hex": "#8B008B" },
  { "name": "DarkOliveGreen", "hex": "#556B2F" },
  { "name": "DarkOrange", "hex": "#FF8C00" },
  { "name": "DarkOrchid", "hex": "#9932CC" },
  { "name": "DarkRed", "hex": "#8B0000" },
  { "name": "DarkSalmon", "hex": "#E9967A" },
  { "name": "DarkSeaGreen", "hex": "#8FBC8F" },
  { "name": "DarkSlateBlue", "hex": "#483D8B" },
  { "name": "DarkSlateGray", "hex": "#2F4F4F" },
  { "name": "DarkSlateGrey", "hex": "#2F4F4F" },
  { "name": "DarkTurquoise", "hex": "#00CED1" },
  { "name": "DarkViolet", "hex": "#9400D3" },
  { "name": "DeepPink", "hex": "#FF1493" },
  { "name": "DeepSkyBlue", "hex": "#00BFFF" },
  { "name": "DimGray", "hex": "#696969" },
  { "name": "DimGrey", "hex": "#696969" },
  { "name": "DodgerBlue", "hex": "#1E90FF" },
  { "name": "FireBrick", "hex": "#B22222" },
  { "name": "FloralWhite", "hex": "#FFFAF0" },
  { "name": "ForestGreen", "hex": "#228B22" },
  { "name": "Fuchsia", "hex": "#FF00FF" },
  { "name": "Gainsboro", "hex": "#DCDCDC" },
  { "name": "GhostWhite", "hex": "#F8F8FF" },
  { "name": "Gold", "hex": "#FFD700" },
  { "name": "GoldenRod", "hex": "#DAA520" },
  { "name": "Gray", "hex": "#808080" },
  { "name": "Grey", "hex": "#808080" },
  { "name": "Green", "hex": "#008000" },
  { "name": "GreenYellow", "hex": "#ADFF2F" },
  { "name": "HoneyDew", "hex": "#F0FFF0" },
  { "name": "HotPink", "hex": "#FF69B4" },
  { "name": "IndianRed", "hex": "#CD5C5C" },
  { "name": "Indigo", "hex": "#4B0082" },
  { "name": "Ivory", "hex": "#FFFFF0" },
  { "name": "Khaki", "hex": "#F0E68C" },
  { "name": "Lavender", "hex": "#E6E6FA" },
  { "name": "LavenderBlush", "hex": "#FFF0F5" },
  { "name": "LawnGreen", "hex": "#7CFC00" },
  { "name": "LemonChiffon", "hex": "#FFFACD" },
  { "name": "LightBlue", "hex": "#ADD8E6" },
  { "name": "LightCoral", "hex": "#F08080" },
  { "name": "LightCyan", "hex": "#E0FFFF" },
  { "name": "LightGoldenRodYellow", "hex": "#FAFAD2" },
  { "name": "LightGray", "hex": "#D3D3D3" },
  { "name": "LightGrey", "hex": "#D3D3D3" },
  { "name": "LightGreen", "hex": "#90EE90" },
  { "name": "LightPink", "hex": "#FFB6C1" },
  { "name": "LightSalmon", "hex": "#FFA07A" },
  { "name": "LightSeaGreen", "hex": "#20B2AA" },
  { "name": "LightSkyBlue", "hex": "#87CEFA" },
  { "name": "LightSlateGray", "hex": "#778899" },
  { "name": "LightSlateGrey", "hex": "#778899" },
  { "name": "LightSteelBlue", "hex": "#B0C4DE" },
  { "name": "LightYellow", "hex": "#FFFFE0" },
  { "name": "Lime", "hex": "#00FF00" },
  { "name": "LimeGreen", "hex": "#32CD32" },
  { "name": "Linen", "hex": "#FAF0E6" },
  { "name": "Magenta", "hex": "#FF00FF" },
  { "name": "Maroon", "hex": "#800000" },
  { "name": "MediumAquaMarine", "hex": "#66CDAA" },
  { "name": "MediumBlue", "hex": "#0000CD" },
  { "name": "MediumOrchid", "hex": "#BA55D3" },
  { "name": "MediumPurple", "hex": "#9370DB" },
  { "name": "MediumSeaGreen", "hex": "#3CB371" },
  { "name": "MediumSlateBlue", "hex": "#7B68EE" },
  { "name": "MediumSpringGreen", "hex": "#00FA9A" },
  { "name": "MediumTurquoise", "hex": "#48D1CC" },
  { "name": "MediumVioletRed", "hex": "#C71585" },
  { "name": "MidnightBlue", "hex": "#191970" },
  { "name": "MintCream", "hex": "#F5FFFA" },
  { "name": "MistyRose", "hex": "#FFE4E1" },
  { "name": "Moccasin", "hex": "#FFE4B5" },
  { "name": "NavajoWhite", "hex": "#FFDEAD" },
  { "name": "Navy", "hex": "#000080" },
  { "name": "OldLace", "hex": "#FDF5E6" },
  { "name": "Olive", "hex": "#808000" },
  { "name": "OliveDrab", "hex": "#6B8E23" },
  { "name": "Orange", "hex": "#FFA500" },
  { "name": "OrangeRed", "hex": "#FF4500" },
  { "name": "Orchid", "hex": "#DA70D6" },
  { "name": "PaleGoldenRod", "hex": "#EEE8AA" },
  { "name": "PaleGreen", "hex": "#98FB98" },
  { "name": "PaleTurquoise", "hex": "#AFEEEE" },
  { "name": "PaleVioletRed", "hex": "#DB7093" },
  { "name": "PapayaWhip", "hex": "#FFEFD5" },
  { "name": "PeachPuff", "hex": "#FFDAB9" },
  { "name": "Peru", "hex": "#CD853F" },
  { "name": "Pink", "hex": "#FFC0CB" },
  { "name": "Plum", "hex": "#DDA0DD" },
  { "name": "PowderBlue", "hex": "#B0E0E6" },
  { "name": "Purple", "hex": "#800080" },
  { "name": "RebeccaPurple", "hex": "#663399" },
  { "name": "Red", "hex": "#FF0000" },
  { "name": "RosyBrown", "hex": "#BC8F8F" },
  { "name": "RoyalBlue", "hex": "#4169E1" },
  { "name": "SaddleBrown", "hex": "#8B4513" },
  { "name": "Salmon", "hex": "#FA8072" },
  { "name": "SandyBrown", "hex": "#F4A460" },
  { "name": "SeaGreen", "hex": "#2E8B57" },
  { "name": "SeaShell", "hex": "#FFF5EE" },
  { "name": "Sienna", "hex": "#A0522D" },
  { "name": "Silver", "hex": "#C0C0C0" },
  { "name": "SkyBlue", "hex": "#87CEEB" },
  { "name": "SlateBlue", "hex": "#6A5ACD" },
  { "name": "SlateGray", "hex": "#708090" },
  { "name": "SlateGrey", "hex": "#708090" },
  { "name": "Snow", "hex": "#FFFAFA" },
  { "name": "SpringGreen", "hex": "#00FF7F" },
  { "name": "SteelBlue", "hex": "#4682B4" },
  { "name": "Tan", "hex": "#D2B48C" },
  { "name": "Teal", "hex": "#008080" },
  { "name": "Thistle", "hex": "#D8BFD8" },
  { "name": "Tomato", "hex": "#FF6347" },
  { "name": "Turquoise", "hex": "#40E0D0" },
  { "name": "Violet", "hex": "#EE82EE" },
  { "name": "Wheat", "hex": "#F5DEB3" },
  { "name": "White", "hex": "#FFFFFF" },
  { "name": "WhiteSmoke", "hex": "#F5F5F5" },
  { "name": "Yellow", "hex": "#FFFF00" },
  { "name": "YellowGreen", "hex": "#9ACD32" }
]

def get_wikipedia_translations(term):
    # Try to clean CamelCase for search
    search_term = re.sub(r'([a-z])([A-Z])', r'\1 \2', term)
    wiki_url = "https://en.wikipedia.org/w/api.php"
    
    # 1. Search
    s_params = { "action": "query", "list": "search", "srsearch": search_term, "format": "json" }
    try:
        s_resp = requests.get(wiki_url, params=s_params, headers={"User-Agent": USER_AGENT}).json()
        results = s_resp.get("query", {}).get("search", [])
        if not results: return { 'en': search_term }
        title = results[0]['title']
        
        # 2. Get langlinks
        l_params = { "action": "query", "prop": "langlinks", "titles": title, "lllimit": 500, "format": "json" }
        l_resp = requests.get(wiki_url, params=l_params, headers={"User-Agent": USER_AGENT}).json()
        pages = l_resp.get("query", {}).get("pages", {})
        translations = { 'en': title }
        for pid in pages:
            if int(pid) < 0: continue
            links = pages[pid].get("langlinks", [])
            for link in links:
                lang = link.get("lang")
                val = link.get("*")
                if lang in langs:
                    translations[lang] = val
        return translations
    except:
        return { 'en': search_term }

def process():
    cards_to_insert = []
    
    # 140 colors, levels 1-20 -> 7 colors per level
    for i, color in enumerate(colors):
        level = (i // 7) + 1
        if level > 20: level = 20
        
        name = color['name']
        hex_code = color['hex']
        display_name = f"{name} ({hex_code})"
        
        print(f"Processing {display_name} (Level {level})...")
        
        translations = get_wikipedia_translations(name)
        
        loc_data = {}
        for lang in langs:
            # For colors, we'll use "TranslatedName (HEX)"
            translated_name = translations.get(lang, name)
            loc_data[lang] = {
                "answer": f"{translated_name} ({hex_code})",
                "prompt": "",
                "audio_url": None
            }
        
        loc_data["global"] = {
            "answer": display_name,
            "prompt": "",
            "audio_url": None,
            "video_url": "",
            "image_urls": [] # No images as requested
        }
        
        cards_to_insert.append({
            "id": str(uuid.uuid4()),
            "subject_id": subject_id,
            "level": level,
            "owner_id": owner_id,
            "is_public": True,
            "test_mode": "image_to_text", # Engine will handle visualization
            "localized_data": loc_data
        })

    # Bulk insert in batches of 50 to avoid timeout/size issues
    batch_size = 50
    for i in range(0, len(cards_to_insert), batch_size):
        batch = cards_to_insert[i:i+batch_size]
        ins_resp = requests.post(f"{url_base}/rest/v1/cards", headers={**headers, "Content-Type": "application/json", "Prefer": "return=minimal"}, json=batch)
        print(f"Inserted batch {i//batch_size + 1}: {ins_resp.status_code}")

if __name__ == "__main__":
    process()
