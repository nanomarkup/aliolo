import sys
import requests
import json
import re

URL = "https://mltdjjszycfmokwqsqxm.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
headers = {"apikey": KEY, "Authorization": "Bearer " + KEY, "Content-Type": "application/json"}

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 generate_clean_sqls_by_subject.py \"<Subject Name>\"")
        sys.exit(1)
        
    subject_name = sys.argv[1]

    # 1. Fetch Subject ID
    print(f"Fetching subject '{subject_name}'...")
    res = requests.get(f"{URL}/rest/v1/subjects?select=id,localized_data", headers=headers)
    
    if res.status_code != 200:
        print(f"Failed to fetch subjects. Error: {res.text}")
        sys.exit(1)
        
    subjects = res.json()
    subject_id = None
    for s in subjects:
        glob = s.get("localized_data", {}).get("global", {})
        if glob.get("name") == subject_name:
            subject_id = s["id"]
            break

    if not subject_id:
        print(f"Could not find subject '{subject_name}'. Please ensure the spelling and case are correct.")
        sys.exit(1)

    print(f"Found subject ID: {subject_id}")

    # 2. Fetch cards for this subject
    res = requests.get(f"{URL}/rest/v1/cards?select=id,localized_data&subject_id=eq.{subject_id}", headers=headers)
    if res.status_code != 200:
        print(f"Failed to fetch cards. Error: {res.text}")
        sys.exit(1)
        
    cards = res.json()
    
    if not cards:
        print(f"No cards found for subject '{subject_name}'")
        sys.exit(1)
        
    print(f"Found {len(cards)} cards.")

    langs = ["ar", "bg", "cs", "da", "de", "el", "en", "es", "et", "fi", "fr", "ga", "hi", "hr", "hu", "id", "it", "ja", "ko", "lt", "lv", "mt", "nl", "pl", "pt", "ro", "sk", "sl", "sv", "tl", "tr", "uk", "vi", "zh"]

    sql_statements = []

    for card in cards:
        card_id = card["id"]
        localized = card.get("localized_data", {}) or {}
        global_data = localized.get("global", {})
        
        new_localized = {
            "global": global_data
        }
        
        for lang in langs:
            new_localized[lang] = {"answer": ""}
            
        # Serialize to JSON and handle SQL escaping for single quotes within the JSON string
        json_str = json.dumps(new_localized, indent=2).replace("'", "''")
        
        sql = f"UPDATE cards\nSET localized_data = '{json_str}'::jsonb\nWHERE id = '{card_id}';\n"
        sql_statements.append(sql)

    # Sanitize subject name to create a safe filename
    safe_name = re.sub(r'[^a-zA-Z0-9_]', '_', subject_name.lower())
    output_filename = f"update_all_{safe_name}_clean.sql"

    with open(output_filename, "w") as f:
        f.write("\n".join(sql_statements))

    print(f"Generated {len(sql_statements)} SQL update statements in {output_filename}")

if __name__ == "__main__":
    main()
