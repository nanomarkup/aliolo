import requests
import json
import urllib.parse

URL = "https://mltdjjszycfmokwqsqxm.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
headers = {"apikey": KEY, "Authorization": "Bearer " + KEY, "Content-Type": "application/json"}

# 1. Fetch Dog Breeds subject ID
res = requests.get(f"{URL}/rest/v1/subjects?select=id,localized_data", headers=headers)
subjects = res.json()
dog_breeds_id = None
for s in subjects:
    glob = s.get("localized_data", {}).get("global", {})
    if glob.get("name") == "Dog Breeds":
        dog_breeds_id = s["id"]
        break

if not dog_breeds_id:
    print("Could not find Dog Breeds subject")
    exit(1)

# 2. Fetch cards for this subject
res = requests.get(f"{URL}/rest/v1/cards?select=id,localized_data&subject_id=eq.{dog_breeds_id}", headers=headers)
cards = res.json()

langs = ["ar", "bg", "cs", "da", "de", "el", "en", "es", "et", "fi", "fr", "ga", "hi", "hr", "hu", "id", "it", "ja", "ko", "lt", "lv", "mt", "nl", "pl", "pt", "ro", "sk", "sl", "sv", "tl", "tr", "uk", "vi", "zh"]

sql_statements = []

for card in cards:
    card_id = card["id"]
    localized = card.get("localized_data", {})
    global_data = localized.get("global", {})
    
    new_localized = {
        "global": global_data
    }
    
    for lang in langs:
        new_localized[lang] = {"answer": ""}
        
    json_str = json.dumps(new_localized, indent=2)
    sql = f"UPDATE cards\nSET localized_data = '{json_str}'::jsonb\nWHERE id = '{card_id}';\n"
    sql_statements.append(sql)

with open("update_all_dog_breeds_clean.sql", "w") as f:
    f.write("\n".join(sql_statements))

print(f"Generated {len(sql_statements)} SQL update statements in update_all_dog_breeds_clean.sql")
